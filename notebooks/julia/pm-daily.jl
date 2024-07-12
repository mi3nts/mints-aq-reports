using CondaPkg
CondaPkg.add("influxdb-client")
CondaPkg.add("pandas")
using PythonCall
using ProgressMeter
using Dates, TimeZones
using CSV, DataFrames, JSON
using Statistics, LinearAlgebra
using SolarGeometry


using CairoMakie
include("./makie-defaults.jl")
set_theme!(mints_theme)
update_theme!(
    figure_padding=30,
    Axis=(
        xticklabelsize=20,
        yticklabelsize=20,
        xlabelsize=22,
        ylabelsize=22,
        titlesize=25,
    ),
    Colorbar=(
        ticklabelsize=20,
        labelsize=22
    )
)


include("./utils.jl")

creds = JSON.parsefile("./credentials.json")
influx_client = pyimport("influxdb_client")
pandas = pyimport("pandas")
client = influx_client.InfluxDBClient(url="http://mdash.circ.utdallas.edu:8086", token=creds["token"], org=creds["orgname"], bucket=creds["bucket"])
query_api = client.query_api()


d= DateTime(2024, 7, 1, 0, 0, 0)
node = "vaLo Node 01"


dstart = d - Minute(25)
dend = d + Day(1) + Minute(25)

query_ips = """
from(bucket: "SharedAirDFW")
  |> range(start: time(v: "$(dstart)Z"), stop: time(v: "$(dend)Z"))
  |> filter(fn: (r) => r["device_name"] == "$(node)")
  |> filter(fn: (r) => r["_measurement"] == "IPS7100")
  |> filter(fn: (r) => r["_field"] == "pm0_1" or r["_field"] == "pm0_3" or r["_field"] == "pm0_5" or r["_field"] == "pm1_0" or r["_field"] == "pm2_5" or r["_field"] == "pm5_0"  or r["_field"] == "pm10_0")
  |> aggregateWindow(every: 1m, period: 10m, offset:-5m,  fn: mean, createEmpty: true)
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "pm0_1", "pm0_3", "pm0_5", "pm1_0", "pm2_5", "pm5_0", "pm10_0"])
"""

query_bme = """
from(bucket: "SharedAirDFW")
  |> range(start: time(v: "$(dstart)Z"), stop: time(v: "$(dend)Z"))
  |> filter(fn: (r) => r["device_name"] == "$(node)")
  |> filter(fn: (r) => r["_measurement"] == "BME280V2")
  |> filter(fn: (r) => r["_field"] == "temperature" or r["_field"] == "pressure" or r["_field"] == "humidity" or r["_field"] == "dewPoint")
  |> aggregateWindow(every: 1m, period: 10m, offset:-5m,  fn: mean, createEmpty: true)
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "temperature", "pressure", "humidity", "dewPoint"])
"""

query_rg15 = """
from(bucket: "SharedAirDFW")
  |> range(start: time(v: "$(dstart)Z"), stop: time(v: "$(dend)Z"))
  |> filter(fn: (r) => r["device_name"] == "$(node)")
  |> filter(fn: (r) => r["_measurement"] == "RG15")
  |> filter(fn: (r) => r["_field"] == "rainPerInterval" or r["_field"] == "accumulation")
  |> aggregateWindow(every: 1m, period: 10m, offset:-5m,  fn: mean, createEmpty: true)
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "rainPerInterval"])
"""

query_scd30 = """
from(bucket: "SharedAirDFW")
  |> range(start: time(v: "$(dstart)Z"), stop: time(v: "$(dend)Z"))
  |> filter(fn: (r) => r["device_name"] == "$(node)")
  |> filter(fn: (r) => r["_measurement"] == "SCD30V2")
  |> filter(fn: (r) => r["_field"] == "co2" or r["_field"] == "temperature")
  |> aggregateWindow(every: 1m, period: 10m, offset:-5m,  fn: mean, createEmpty: true)
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "co2"])
"""

let
    df_ips = query_api.query_data_frame(query_ips)
    df_ips = df_ips.drop(["result", "table"], axis=1)
    df_ips.to_csv("ips.csv")

    df_bme = query_api.query_data_frame(query_bme)
    df_bme = df_bme.drop(["result", "table"], axis=1)
    df_bme.to_csv("bme.csv")

    df_rg = query_api.query_data_frame(query_rg15)
    df_rg = df_rg.drop(["result", "table"], axis=1)
    df_rg.to_csv("rg.csv")

    df_scd = query_api.query_data_frame(query_scd30)
    df_scd = df_scd.drop(["result", "table"], axis=1)
    df_scd.to_csv("scd.csv")
end

function process_df(df_path, date)
    df = CSV.read(df_path, DataFrame)
    df = df[:, Not(:Column1)]
    rename!(df, :_time => :datetime)
    df.datetime = parse_datetime.(df.datetime)

    # keep only relevant days since we padded the data
    idx_keep = [Date(di) == date for di ∈ df.datetime]
    df = df[idx_keep, :]
    dropmissing!(df)

    return df
end


# position of vaLo Node 01
pos = (;lat=32.967465, lon=-96.725647, alt=207.)

df = process_df("ips.csv", Date(d))
df = leftjoin(df, process_df("bme.csv", Date(d)), on=:datetime)
df = leftjoin(df, process_df("rg.csv", Date(d)), on=:datetime)
df = leftjoin(df, process_df("scd.csv", Date(d)), on=:datetime)

# add in solar elevation
df.sol_el = [solar_azimuth_altitude(df.datetime[i], pos.lat, pos.lon, pos.alt)[2] for i in 1:nrow(df)]
df.sol_zenith = 90 .- df.sol_el

# add in dt in hours
df.dt = [(v.value)/(1000*60*60) for v in (df.datetime .- df.datetime[1])]

df.rainPerInterval = [ismissing(r) || isnan(r) ? 0.0 : r for r in df.rainPerInterval]


# visualize the time series
cline = colorant"#ebc334"
cfill = colorant"#f0dfa1"
crain = colorant"#2469d6"

# fig = Figure(size= 0.5 .* (2480, 3508));
fig = Figure(size=(595, 842), px_per_unit=20);
gl = fig[1,1] = GridLayout();

yticklabelsize=10
xticklabelsize=12
titlesize=10
titlegap=2

ax_rainfall = Axis(gl[1,1],
                   xticksvisible=false, xticklabelsvisible=false,
                   xticks=(0:3:24),
                   yminorgridvisible=true, yticklabelsize=yticklabelsize,
                   yticks=([0, 8], ["0", "8"]),
                   title="Rainfall (mm/hr)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
                   )
axr_rainfall = Axis(gl[1,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_rainfall)
linkyaxes!(axr_rainfall, ax_rainfall)


ax_humidity = Axis(gl[2,1],
                   xticksvisible=false, xticklabelsvisible=false,
                   xticks=(0:3:24),
                   yminorgridvisible=true, yticklabelsize=yticklabelsize,
                   yticks=([0, 100], ["0", "100"]),
                   title="Humidity (%)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
                   )
axr_humidity = Axis(gl[2,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_humidity)
linkyaxes!(axr_humidity, ax_humidity)

ax_temp = Axis(gl[3,1],
               xticksvisible=false, xticklabelsvisible=false,
               xticks=(0:3:24),
               yminorgridvisible=true, yticklabelsize=yticklabelsize,
               yticks=([0, 50], ["0", "50"]),
               title="— Temperature (°C)    -- Dew Point (°C)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
               )
axr_temp = Axis(gl[3,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_temp)
linkyaxes!(axr_temp, ax_temp)

ax_sun = Axis(gl[4,1],
              xticksvisible=false, xticklabelsvisible=false,
              xticks=(0:3:24),
              yminorgridvisible=true,yticklabelsize=yticklabelsize,
              yticks=([0, 90], ["0", "90"]),
              title="Solar Elevation (degrees)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
              )
axr_sun = Axis(gl[4,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_sun)
linkyaxes!(axr_sun, ax_sun)

ax_0_1 = Axis(gl[5,1],
          xticksvisible=false, xticklabelsvisible=false,
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm0_1)), ceil(Int, maximum(df.pm0_1))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 0.1 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_0_1 = Axis(gl[5,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_0_1)
linkyaxes!(axr_0_1, ax_0_1)


ax_0_3 = Axis(gl[6,1],
          xticksvisible=false, xticklabelsvisible=false,
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm0_3)), ceil(Int, maximum(df.pm0_3))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 0.3 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_0_3 = Axis(gl[6,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_0_3)
linkyaxes!(axr_0_3, ax_0_3)


ax_0_5 = Axis(gl[7,1],
          xticksvisible=false, xticklabelsvisible=false,
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm0_5)), ceil(Int, maximum(df.pm0_5))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 0.5 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_0_5 = Axis(gl[7,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_0_5)
linkyaxes!(axr_0_5, ax_0_5)


ax_1_0 = Axis(gl[8,1],
          xticksvisible=false, xticklabelsvisible=false,
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm1_0)), ceil(Int, maximum(df.pm1_0))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 1 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_1_0 = Axis(gl[8,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_1_0)
linkyaxes!(axr_1_0, ax_1_0)


ax_2_5 = Axis(gl[9,1],
          xticksvisible=false, xticklabelsvisible=false,
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm2_5)), ceil(Int, maximum(df.pm2_5))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 2.5 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_2_5 = Axis(gl[9,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_2_5)
linkyaxes!(axr_2_5, ax_2_5)


ax_5_0 = Axis(gl[10,1],
              xticksvisible=false, xticklabelsvisible=false,
              xticks=(0:3:24),
              yticklabelsize=yticklabelsize,
              xticklabelsize=xticklabelsize,
              yticks = ([floor(Int, minimum(df.pm5_0)), ceil(Int, maximum(df.pm5_0))]),
              ylabelsize=15,
              xlabelsize=15,
              title="PM 5 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
              );
axr_5_0 = Axis(gl[10,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_5_0)
linkyaxes!(axr_5_0, ax_5_0)

ax_10_0 = Axis(gl[11,1],
          xlabel="$(Date(df.datetime[1])) (UTC)",
          xticks=(0:3:24),
          yticklabelsize=yticklabelsize,
          xticklabelsize=xticklabelsize,
          yticks = ([floor(Int, minimum(df.pm10_0)), ceil(Int, maximum(df.pm10_0))]),
          ylabelsize=15,
          xlabelsize=15,
          title="PM 10 (μg/m³)", titlefont=:regular, titlealign=:left, titlesize=titlesize, titlegap=titlegap,
          );
axr_10_0 = Axis(gl[11,2],
                leftspinevisible=false, rightspinevisible=false,
                bottomspinevisible=false, topspinevisible=false,
                )
hidedecorations!(axr_10_0)
linkyaxes!(axr_10_0, ax_10_0)


linkxaxes!(ax_sun, ax_temp, ax_humidity, ax_rainfall, ax_0_1, ax_0_3, ax_0_5, ax_1_0, ax_2_5, ax_5_0, ax_10_0)
xlims!(ax_10_0, 0, 24)


# plot solar elevation
l_s = lines!(ax_sun, df.dt, df.sol_el, color=cline, linewidth=3)
band!(ax_sun, df.dt, zeros(nrow(df)), df.sol_el, color=cfill)
density!(axr_sun, df.sol_el[df.sol_el .> 0], direction = :y, color=(cline, 0.5), strokecolor=cline, strokewidth=2)
ylims!(ax_sun, 0, 90)
ylims!(axr_sun, 0, 90)

# plot temperature
l_t = lines!(ax_temp, df.dt, df.temperature, color=mints_colors[2], linewidth=2, label="Temperature")
l_tt = lines!(ax_temp, df.dt, df.dewPoint, color=mints_colors[2], linewidth=1, linestyle=:dash, label="Dew Point")
density!(axr_temp, df.temperature, direction = :y, color=(mints_colors[2], 0.5), strokecolor=mints_colors[2], strokewidth=2)
ylims!(ax_temp, 0, 50)
ylims!(axr_temp, 0, 50)

# plot humidity
l_h = lines!(ax_humidity, df.dt, df.humidity, color=crain, linewidth=2)
density!(axr_humidity, df.humidity, direction = :y, color=(crain, 0.5), strokecolor=crain, strokewidth=2)
ylims!(ax_humidity, 0, 100)
ylims!(axr_humidity, 0, 100)

# plot rainfall
l_r = lines!(ax_rainfall, df.dt, df.rainPerInterval, color=(:purple, 0.75), linewidth=2)
density!(axr_rainfall, df.rainPerInterval, direction = :y, color=(:purple, 0.5), strokecolor=:purple, strokewidth=2)
ylims!(ax_rainfall, 0, 8)
ylims!(axr_rainfall, 0, 8)

# plot PM 0.1
lines!(ax_0_1, df.dt, df.pm0_1, color=:gray)
density!(axr_0_1, df.pm0_1, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_0_1, floor(Int, minimum(df.pm0_1)), ceil(Int, maximum(df.pm0_1)))
ylims!(axr_0_1, floor(Int, minimum(df.pm0_1)), ceil(Int, maximum(df.pm0_1)))

# plot PM 0.3
lines!(ax_0_3, df.dt, df.pm0_3, color=:gray)
density!(axr_0_3, df.pm0_3, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_0_3, floor(Int, minimum(df.pm0_3)), ceil(Int, maximum(df.pm0_3)))
ylims!(axr_0_3, floor(Int, minimum(df.pm0_3)), ceil(Int, maximum(df.pm0_3)))

# plot PM 0.5
lines!(ax_0_5, df.dt, df.pm0_5, color=:gray)
density!(axr_0_5, df.pm0_5, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_0_5, floor(Int, minimum(df.pm0_5)), ceil(Int, maximum(df.pm0_5)))
ylims!(axr_0_5, floor(Int, minimum(df.pm0_5)), ceil(Int, maximum(df.pm0_5)))

# plot PM 1.0
lines!(ax_1_0, df.dt, df.pm1_0, color=:gray)
density!(axr_1_0, df.pm1_0, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_1_0, floor(Int, minimum(df.pm1_0)), ceil(Int, maximum(df.pm1_0)))
ylims!(axr_1_0, floor(Int, minimum(df.pm1_0)), ceil(Int, maximum(df.pm1_0)))

# plot PM 2.5
lines!(ax_2_5, df.dt, df.pm2_5, color=:gray)
density!(axr_2_5, df.pm2_5, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_2_5, floor(Int, minimum(df.pm2_5)), ceil(Int, maximum(df.pm2_5)))
ylims!(axr_2_5, floor(Int, minimum(df.pm2_5)), ceil(Int, maximum(df.pm2_5)))

# plot PM 5.0
lines!(ax_5_0, df.dt, df.pm5_0, color=:gray)
density!(axr_5_0, df.pm5_0, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_5_0, floor(Int, minimum(df.pm5_0)), ceil(Int, maximum(df.pm5_0)))
ylims!(axr_5_0, floor(Int, minimum(df.pm5_0)), ceil(Int, maximum(df.pm5_0)))

# plot PM 10.0
lines!(ax_10_0, df.dt, df.pm10_0, color=:gray)
density!(axr_10_0, df.pm10_0, direction = :y, color=(:gray, 0.5), strokecolor=:gray, strokewidth=2)
ylims!(ax_10_0, floor(Int, minimum(df.pm10_0)), ceil(Int, maximum(df.pm10_0)))
ylims!(axr_10_0, floor(Int, minimum(df.pm10_0)), ceil(Int, maximum(df.pm10_0)))

size_extra = (1/5)/4
pm_size = (4/5)/7

rowsize!(gl, 1, Relative(size_extra))
rowsize!(gl, 2, Relative(size_extra))
rowsize!(gl, 3, Relative(size_extra))
rowsize!(gl, 4, Relative(size_extra))
rowsize!(gl, 5, Relative(pm_size))
rowsize!(gl, 6, Relative(pm_size))
rowsize!(gl, 7, Relative(pm_size))
rowsize!(gl, 8, Relative(pm_size))
rowsize!(gl, 9, Relative(pm_size))
rowsize!(gl, 10, Relative(pm_size))
rowsize!(gl, 11, Relative(pm_size))

rowgap!(gl, 8)
colgap!(gl, 1)
colsize!(gl, 2, Relative(0.08))

fig

save("pm-full-page.png", fig)

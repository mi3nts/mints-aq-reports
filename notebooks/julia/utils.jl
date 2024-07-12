function parse_datetime(dt)
    dt_out = String(dt)

    if occursin(".", dt)
        try
            # return ZonedDateTime(dt, "yyyy-mm-dd HH:MM:SS.sssssszzzz")
            return DateTime(dt[1:end-6], dateformat"yyyy-mm-dd HH:MM:SS.ssssss")
        catch e
            return missing
        end
    else
        try
            # return ZonedDateTime(dt, "yyyy-mm-dd HH:MM:SSzzzz")
            return DateTime(dt[1:end-6], dateformat"yyyy-mm-dd HH:MM:SS")
        catch e
            return missing
        end
    end
end

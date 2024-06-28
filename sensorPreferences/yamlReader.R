# Install the yaml package if not already installed
if (!require("yaml")) {
  install.packages("yaml")
}

# Load the yaml library
library(yaml)

# Load the YAML file
preferences <- yaml.load_file("sensorPreferences.yaml")



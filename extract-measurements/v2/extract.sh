# Global configurations
[agent]
  interval = "1s"
  round_interval = false
  metric_batch_size = 10000
  metric_buffer_limit = 500000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  debug = true
  quiet = false
  hostname = ""
  omit_hostname = false


######### ATNOG-TEST5 ###############0
[[inputs.snmp]]
  agents = ["udp://192.168.88.143:161"]
  version = 1
  community = "it-atnog"
  name_override = "pdu143"
  interval = "1s"
  [[inputs.snmp.field]]
    oid = "1.3.6.1.4.1.534.6.6.7.6.5.1.3.0.19"
    name = "atnog-test5"
[inputs.snmp.tags]
plugin = "pdu"
placement = "pdu143"
rack = "r2"
server = "atnog-test5"

[[inputs.snmp]]
  agents = ["udp://192.168.88.144:161"]
  version = 1
  community = "it-atnog"
  name_override = "pdu144"
  interval = "1s"
  [[inputs.snmp.field]]
    oid = "1.3.6.1.4.1.534.6.6.7.6.5.1.3.0.19"
    name = "atnog-test5"
[inputs.snmp.tags]
plugin = "pdu"
placement = "pdu144"
rack = "r2"
server = "atnog-test5"


# MQTT consumer for the PDU 143
#[[inputs.mqtt_consumer]]
#  servers = ["ssl://192.168.88.143:8883"]  # Replace with actual broker IP/port
#  topics = ["mbdetnrs/2.0/powerDistributions/1/outlets/19/measures"]
#  client_id = "telegraf-pdu_143"
#  data_format = "json" # Assume the payload is JSON
#  qos = 0
#  persistent_session = false
#  connection_timeout = "30s"
#  name_override = "pdu_energy_143"
# # TLS Config
#  tls_ca = "/etc/telegraf/certs/pdu-r2-l.crt"
#  tls_cert= "/etc/telegraf/certs/client.crt"
#  tls_key= "/etc/telegraf/certs/client.key"
#  ## Use TLS but skip chain & host verification
#  insecure_skip_verify = true
#  [inputs.mqtt_consumer.tags]
#    source = "pdu143"
#    server = "atnog-test5"

# MQTT consumer for the PDU 144
#[[inputs.mqtt_consumer]]
#  servers = ["ssl://192.168.88.144:8883"]  # Replace with actual broker IP/port
#  topics = ["mbdetnrs/2.0/powerDistributions/1/outlets/19/measures"]
#  client_id = "telegraf-pdu_144"
#  data_format = "json" # Assume the payload is JSON
#  qos = 0
#  persistent_session = false
#  connection_timeout = "30s"
#  name_override = "pdu_energy_144"
#  # TLS Config
#  tls_ca = "/etc/telegraf/certs/pdu-r2-r.crt"
#  tls_cert= "/etc/telegraf/certs/client.crt"
#  tls_key= "/etc/telegraf/certs/client.key"
#  ## Use TLS but skip chain & host verification
#  insecure_skip_verify = true
#  [inputs.mqtt_consumer.tags]
#    source = "pdu144"
#    server = "atnog-test5"

# MQTT consumer for the Shelly on PDU 143
[[inputs.mqtt_consumer]]
  servers = ["tcp://localhost:1883"]
  topics = ["pdu143/status/pdu143"]
  client_id = "telegraf-shelly-143"
  data_format = "json" # Assume the payload is JSON
  qos = 0
  persistent_session = false
  connection_timeout = "30s"
  name_override = "shelly_pdu_143"
  insecure_skip_verify = true
  [inputs.mqtt_consumer.tags]
    server = "atnog-test5"

# MQTT consumer for the Shelly on PDU 144
[[inputs.mqtt_consumer]]
  servers = ["tcp://localhost:1883"]
  topics = ["pdu144/status/pdu144"]
  client_id = "telegraf-shelly-144"
  data_format = "json" # Assume the payload is JSON
  qos = 0
  persistent_session = false
  connection_timeout = "30s"
  name_override = "shelly_pdu_144"
  insecure_skip_verify = true
  [inputs.mqtt_consumer.tags]
    server = "atnog-test5"

# MQTT consumer for the Clamp Shelly
[[inputs.mqtt_consumer]]
  servers = ["tcp://localhost:1883"]
  topics = ["clamp143/status/+"]
  topic_tag = "topic" # Separate the different topics with a tag
  client_id = "telegraf-clamp-shelly"
  data_format = "json" # Assume the payload is JSON
  qos = 0
  persistent_session = false
  connection_timeout = "30s"
  name_override = "clamp-shelly"
  insecure_skip_verify = true
  [inputs.mqtt_consumer.tags]
    server = "atnog-test5"

# MQTT consumer for the IPMI tool
#[[inputs.mqtt_consumer]]
#  servers = ["tcp://10.255.35.77:1883"]  # Replace with actual broker IP/port
#  topics = ["ipmi"]
#  client_id = "telegraf-ipmi"
#  name_override = "ipmi"
#  data_format = "json" # Assume the payload is JSON
#  qos = 0
#  persistent_session = false
#  connection_timeout = "30s"
#  insecure_skip_verify = true

# SNMP consumer for the IPMI  snmpwalk -v1 -c it-atnog 192.168.88.142 .1.3.6.1.4.1.232.6.2.9.3.1.7
[[inputs.snmp]]
  agents = ["udp://192.168.88.142:161"]
  version = 1
  community = "it-atnog"
  timeout = "5s"
  retries = 2
  agent_host_tag = "source"
  name_override = "ipmi_snmp"
    [[inputs.snmp.field]]
      name = "psu1"
      oid  = "1.3.6.1.4.1.232.6.2.9.3.1.7.0.1"
    [[inputs.snmp.field]]
      name = "psu2"
      oid  = "1.3.6.1.4.1.232.6.2.9.3.1.7.0.2"
    [inputs.snmp.tags]
      server = "atnog-test5"

# Prometheus for Scaphandre
[[inputs.prometheus]]
  interval = "3s"
  urls = [ "http://10.255.35.77:8080/metrics",]
  metric_version = 2
  name_override = "scaphandre"
  fieldinclude = [ "scaph_host_power_microwatts", "scaph_domain_power_microwatts","scaph_socket_power_microwatts", "*host_energy*","scaph_process_power_consumption_microwatts"]
  [inputs.prometheus.tags]
    server = "atnog-test5"

# Prometheus for Alumet
[[inputs.prometheus]]
  interval = "2s"
  urls = [ "http://10.255.35.77:9091/metrics",]
  metric_version = 2
  name_override = "alumet"
  fieldinclude = [ "rapl_consumed_energy_J_alumet"]
  [inputs.prometheus.tags]
    server = "atnog-test5"

# Prometheus for Kepler
[[inputs.prometheus]]
  interval = "1s"
  urls = [ "http://10.255.35.77:9102/metrics",]
  metric_version = 2
  name_override = "kepler"
  [inputs.prometheus.tags]
    server = "atnog-test5"


######### LAPTOP HP ###############0
####PDU

[[inputs.snmp]]
  agents = ["udp://10.255.35.6:161"]
  version = 1
  community = "it-atnog"
  name_override = "pdu125"
  interval = "1s"
  [[inputs.snmp.field]]
    oid = "1.3.6.1.4.1.534.6.6.7.6.5.1.3.0.1"
    name = "ultraP3"
[inputs.snmp.tags]
plugin = "pdu"
placement = "table"
rack = "r125"
server = "ultraP3"

# Prometheus for Scaphandre
[[inputs.prometheus]]
  interval = "3s"
  urls = [ "http://10.255.35.141:8080/metrics",]
  metric_version = 2
  name_override = "scaphandre"
  fieldinclude = [ "scaph_host_power_microwatts", "scaph_domain_power_microwatts","scaph_socket_power_microwatts", "*host_energy*","scaph_process_power_consumption_microwatts"]
  [inputs.prometheus.tags]
    server = "laptopHP"

# Prometheus for Alumet
[[inputs.prometheus]]
  interval = "1s"
  urls = [ "http://10.255.35.141:9091/metrics",]
  metric_version = 2
  name_override = "alumet"
  fieldinclude = [ "rapl_consumed_energy_J_alumet"]
  [inputs.prometheus.tags]
    server = "laptopHP"

# Prometheus for Kepler
[[inputs.prometheus]]
  interval = "1s"
  urls = [ "http://10.255.35.141:9102/metrics",]
  metric_version = 2
  name_override = "kepler"
  [inputs.prometheus.tags]
    server = "laptopHP"


######### ULTRA P3 ###############0

[[inputs.snmp]]
  agents = ["udp://10.255.35.6:161"]
  version = 1
  community = "it-atnog"
  name_override = "pdu125"
  interval = "1s"
  [[inputs.snmp.field]]
    oid = "1.3.6.1.4.1.534.6.6.7.6.5.1.3.0.19"
    name = "laptopHP"
[inputs.snmp.tags]
plugin = "pdu"
placement = "table"
rack = "r125"
server = "laptopHP"

# MQTT consumer for the PDU 125
#[[inputs.mqtt_consumer]]
#  servers = ["ssl://10.255.35.6:8883"]  # Replace with actual broker IP/port
#  topics = ["mbdetnrs/2.0/powerDistributions/1/outlets/1/measures"]
#  client_id = "telegraf-pdu_125"
#  data_format = "json" # Assume the payload is JSON
#  qos = 0
#  persistent_session = false
#  connection_timeout = "30s"
#  name_override = "pdu_energy_125"
#  # TLS Config
#  tls_ca = "/etc/telegraf/certs/pdu-r2-r.crt"
#  tls_cert= "/etc/telegraf/certs/client.crt"
#  tls_key= "/etc/telegraf/certs/client.key"
#  ## Use TLS but skip chain & host verification
#  insecure_skip_verify = true
#  [inputs.mqtt_consumer.tags]
#    source = "pdu125"
#    server = "ultraP3"

# Prometheus for Scaphandre
[[inputs.prometheus]]
  interval = "3s"
  urls = [ "http://10.255.35.143:8080/metrics",]
  metric_version = 2
  name_override = "scaphandre"
  fieldinclude = [ "scaph_host_power_microwatts", "scaph_domain_power_microwatts","scaph_socket_power_microwatts", "*host_energy*","scaph_process_power_consumption_microwatts"]
  [inputs.prometheus.tags]
    server = "ultraP3"

# Prometheus for Alumet
[[inputs.prometheus]]
  interval = "1s"
  urls = [ "http://10.255.35.143:9091/metrics",]
  metric_version = 2
  name_override = "alumet"
  fieldinclude = [ "rapl_consumed_energy_J_alumet"]
  [inputs.prometheus.tags]
    server = "ultraP3"

# Prometheus for Kepler
[[inputs.prometheus]]
  interval = "1s"
  urls = [ "http://10.255.35.143:9102/metrics",]
  metric_version = 2
  name_override = "kepler"
  [inputs.prometheus.tags]
    server = "ultraP3"

################################################################################



#[[outputs.file]]
#  files = ["/dev/stdout"]
#  data_format = "influx"  # You can also use "json", "graphite", etc.

[[outputs.influxdb_v2]]
  urls = ["http://localhost:8086"]
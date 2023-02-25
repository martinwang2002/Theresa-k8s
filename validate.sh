docker run \
-v $(pwd)/ConfigMap/envoy/envoy.yaml:/etc/envoy/envoy.yaml \
envoyproxy/envoy-tools-dev \
/usr/local/bin/schema_validator_tool \
--schema-type bootstrap \
--config-path /etc/envoy/envoy.yaml

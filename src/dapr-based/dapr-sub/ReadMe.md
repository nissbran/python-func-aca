## To run

```bash
dapr run --app-id subscriber --app-protocol http --app-port 5000 --resources-path ../dapr-components python subscriber.py
```

## To run with debugging

This starts the dapr sidecar with hosting the subscriber app. Then just start your subscriber app in your IDE with debugging.

```bash
daprd --app-id subscriber --log-level debug --enable-api-logging --app-protocol http --app-port 5000 --resources-path ../dapr-components
```

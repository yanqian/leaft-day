# Interrupted startup recovery
Original root startup remained active after the user interrupted for design. The duplicate resume startup was stopped before its Xcode phase; original session 2680 retained. Stopped invocation is not pass evidence.
- Failure domain: environment_orchestration
- Harness improvement: check live retained exec sessions before restarting recovery after an interruption; no product change needed.

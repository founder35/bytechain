#!/bin/bash
set -e

# Default values
MONIKER=${MONIKER:-"bytechain-node"}
CHAINID=${CHAINID:-"bytechain_9000-1"}
KEY_NAME=${KEY_NAME:-"validator"}

# Define home directory based on expected bytechaind behavior
# The Dockerfile sets USER bytechain, so HOME is /home/bytechain.
# The default node home is ~/.bytechaind.
HOME_DIR="$HOME/.bytechaind"

# Handle arguments
if [ "$1" = "bytechaind" ]; then
    shift
fi

# Default to "start" if no arguments provided
if [ -z "$1" ]; then
    set -- start
fi

# If command is "start", perform Init and Config steps
if [ "$1" = "start" ]; then
    # Check if initialized
    if [ ! -f "$HOME_DIR/config/genesis.json" ]; then
        echo "Initializing node..."
        
        # Init
        bytechaind init $MONIKER --chain-id $CHAINID --home "$HOME_DIR"

        # Create validator key
        echo "Creating validator key..."
        bytechaind keys add $KEY_NAME --keyring-backend test --home "$HOME_DIR"

        # Add genesis account
        echo "Adding genesis account..."
        # Get address
        ADDR=$(bytechaind keys show $KEY_NAME -a --keyring-backend test --home "$HOME_DIR")
        # Add coins (using aevmos as per current types/coin.go)
        bytechaind add-genesis-account $ADDR 1000000000000000000000aevmos,1000000000000000000000stake --home "$HOME_DIR" --keyring-backend test

        # GenTx
        echo "Generating gentx..."
        bytechaind gentx $KEY_NAME 1000000000000000000stake --chain-id $CHAINID --keyring-backend test --home "$HOME_DIR"

        # Collect GenTxs
        echo "Collecting gentxs..."
        bytechaind collect-gentxs --home "$HOME_DIR"
        
        # Validate genesis
        echo "Validating genesis..."
        bytechaind validate-genesis --home "$HOME_DIR"
    fi

    # ------------------------------------------------------------------
    # CRITICAL: Fix Listen Addresses (127.0.0.1 -> 0.0.0.0)
    # By default, Cosmos SDK binds RPC/API to localhost, which fails in Docker.
    # ------------------------------------------------------------------
    echo "Configuring network listener addresses..."

    # config.toml (RPC, P2P)
    if [ -f "$HOME_DIR/config/config.toml" ]; then
        # RPC laddr (tcp://127.0.0.1:26657 -> tcp://0.0.0.0:26657)
        sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' "$HOME_DIR/config/config.toml"
        # P2P laddr (usually already 0.0.0.0:26656, but ensuring)
        sed -i 's/laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/g' "$HOME_DIR/config/config.toml"
        
        # CORS (allow all)
        sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/g' "$HOME_DIR/config/config.toml"
    fi

    # app.toml (API, gRPC, JSON-RPC/EVM)
    if [ -f "$HOME_DIR/config/app.toml" ]; then
        # API (1317)
        sed -i 's/address = "tcp:\/\/127.0.0.1:1317"/address = "tcp:\/\/0.0.0.0:1317"/g' "$HOME_DIR/config/app.toml"
        sed -i 's/enable = false/enable = true/g' "$HOME_DIR/config/app.toml" # enable API if disabled
        sed -i 's/swagger = false/swagger = true/g' "$HOME_DIR/config/app.toml"

        # gRPC (9090 -> 9092)
        sed -i 's/address = "127.0.0.1:9090"/address = "0.0.0.0:9092"/g' "$HOME_DIR/config/app.toml"
        
        # JSON-RPC (8545)
        sed -i 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/g' "$HOME_DIR/config/app.toml"
        sed -i 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/g' "$HOME_DIR/config/app.toml"
    fi
fi

# Execute command
echo "Executing: bytechaind $@"
exec bytechaind "$@"

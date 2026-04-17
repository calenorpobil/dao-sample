#!/bin/bash

# DAO Voting Platform - Full Development Setup
# Inicia Anvil, deploya contratos y npm dev en un solo comando

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SC_DIR="$PROJECT_ROOT/sc"
WEB_DIR="$PROJECT_ROOT/web"
ANVIL_PORT=8545
ANVIL_RPC="http://127.0.0.1:$ANVIL_PORT"
ANVIL_PID=""

# Get available port starting from 3002 using node
NEXT_PORT=$(node -e "
const net = require('net');
let port = 3002;
const tryPort = (p) => {
    const server = net.createServer();
    server.listen(p, () => {
        server.close();
        console.log(p);
        process.exit(0);
    });
    server.on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
            tryPort(p + 1);
        } else {
            process.exit(1);
        }
    });
    setTimeout(() => process.exit(1), 1000);
};
tryPort(port);
")

# Cleanup function
cleanup() {
    if [ ! -z "$ANVIL_PID" ]; then
        kill $ANVIL_PID 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Kill any existing Next.js servers on ports 3000-3010
echo -e "${YELLOW}🔍 Limpiando servidores anteriores...${NC}"
for port in {3000..3010}; do
    # Try lsof first (Linux/Mac), then fall back to netstat (Windows)
    if command -v lsof &> /dev/null && lsof -i :$port &>/dev/null 2>&1; then
        PID=$(lsof -i :$port | grep node | awk '{print $2}' | head -1)
        if [ ! -z "$PID" ]; then
            echo -e "${YELLOW}⚠️  Matando proceso en puerto $port (PID: $PID)${NC}"
            kill -9 $PID 2>/dev/null || taskkill /PID $PID /F 2>/dev/null || true
            sleep 0.5
        fi
    elif netstat -ano 2>/dev/null | grep -q "LISTENING.*:$port"; then
        PID=$(netstat -ano 2>/dev/null | grep "LISTENING.*:$port" | awk '{print $NF}' | head -1)
        if [ ! -z "$PID" ] && [ "$PID" != "PID" ]; then
            echo -e "${YELLOW}⚠️  Matando proceso en puerto $port (PID: $PID)${NC}"
            taskkill /PID $PID /F 2>/dev/null || true
            sleep 0.5
        fi
    fi
done

# Print header
echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  DAO Voting Platform - Dev Environment  ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}📋 Verificando dependencias...${NC}"

if ! command -v anvil &> /dev/null; then
    echo -e "${RED}❌ Anvil no encontrado${NC}"
    echo "Instala Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Forge no encontrado${NC}"
    echo "Instala Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm no encontrado${NC}"
    echo "Instala Node.js: https://nodejs.org/"
    exit 1
fi

echo -e "${GREEN}✓ Todas las dependencias encontradas${NC}"
echo ""

# Step 1: Start Anvil
echo -e "${YELLOW}🔗 1. Iniciando Anvil...${NC}"

# Check if port is already in use
if netstat -tuln 2>/dev/null | grep -q ":$ANVIL_PORT"; then
    echo -e "${YELLOW}⚠️  Puerto $ANVIL_PORT ya en uso, intentando reutilizar...${NC}"
    ANVIL_RUNNING=true
else
    anvil --host 127.0.0.1 --port $ANVIL_PORT > /tmp/anvil.log 2>&1 &
    ANVIL_PID=$!
    ANVIL_RUNNING=false

    # Wait for Anvil to be ready
    echo -n "Esperando Anvil..."
    for i in {1..30}; do
        if curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $ANVIL_RPC > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        echo -n "."
        sleep 1
    done
fi

echo -e "${GREEN}✓ Anvil corriendo en $ANVIL_RPC${NC}"
echo ""

# Step 2: Build and Deploy Contracts
echo -e "${YELLOW}🏗️  2. Compilando y deployando contratos...${NC}"

cd "$SC_DIR"

# Create .env if doesn't exist
if [ ! -f ".env" ]; then
    cat > .env << EOF
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=$ANVIL_RPC
MINIMUM_BALANCE=100000000000000000
EOF
fi

# Build contracts
forge build 2>&1 | grep -E "^(Compiling|Finished)" || true

# Deploy contracts
DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $ANVIL_RPC \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 2>&1)

# Extract addresses
FORWARDER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP "MinimalForwarder deployed at: \K0x[a-fA-F0-9]{40}" || echo "")
DAO_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP "DAOVoting deployed at: \K0x[a-fA-F0-9]{40}" || echo "")

if [ -z "$FORWARDER_ADDRESS" ] || [ -z "$DAO_ADDRESS" ]; then
    echo -e "${RED}❌ Error en el deployment${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Contratos deployados${NC}"
echo "  MinimalForwarder: $FORWARDER_ADDRESS"
echo "  DAOVoting:        $DAO_ADDRESS"
echo ""

# Step 3: Generate ABIs
echo -e "${YELLOW}📋 3. Generando ABIs...${NC}"

if command -v jq &> /dev/null; then
    mkdir -p "$WEB_DIR/lib"
    jq -r '.abi' out/DAOVoting.sol/DAOVoting.json > "$WEB_DIR/lib/DAOVoting.abi.json"
    jq -r '.abi' out/MinimalForwarder.sol/MinimalForwarder.json > "$WEB_DIR/lib/MinimalForwarder.abi.json"
    echo -e "${GREEN}✓ ABIs generados${NC}"
else
    echo -e "${YELLOW}⚠️  jq no encontrado, saltando generación de ABIs${NC}"
    echo "Instala jq para automaticar esto: apt-get install jq (Linux) o brew install jq (Mac)"
fi

echo ""

# Step 4: Configure environment
echo -e "${YELLOW}⚙️  4. Configurando variables de entorno...${NC}"

cat > "$WEB_DIR/.env.local" << EOF
NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=$DAO_ADDRESS
NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=$FORWARDER_ADDRESS
RELAYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RELAYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
RPC_URL=$ANVIL_RPC
EOF

echo -e "${GREEN}✓ Variables de entorno configuradas${NC}"
echo ""

# Step 5: Install npm dependencies
echo -e "${YELLOW}📦 5. Instalando dependencias...${NC}"

cd "$WEB_DIR"

if [ ! -d "node_modules" ]; then
    npm install --legacy-peer-deps 2>&1 | tail -5
    echo -e "${GREEN}✓ Dependencias instaladas${NC}"
else
    echo -e "${GREEN}✓ Dependencias ya instaladas${NC}"
fi

echo ""

# Step 6: Display summary and start dev server
echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║     ✅ Setup completado exitosamente    ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BLUE}📊 Información de Deployment:${NC}"
echo "  MinimalForwarder: $FORWARDER_ADDRESS"
echo "  DAOVoting:        $DAO_ADDRESS"
echo ""

echo -e "${BLUE}🌐 Servicios:${NC}"
echo "  Anvil:  $ANVIL_RPC"
echo "  Web:    http://localhost:$NEXT_PORT"
echo ""

echo -e "${BLUE}💰 Cuenta de Prueba (importar en MetaMask):${NC}"
echo "  Address:     0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
echo "  Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
echo ""

echo -e "${YELLOW}⚙️  Configuración de MetaMask:${NC}"
echo "  Red:     Localhost"
echo "  RPC:     $ANVIL_RPC"
echo "  Chain:   31337"
echo ""

echo -e "${YELLOW}🚀 Iniciando servidor de desarrollo...${NC}"
echo -e "${RED}Presiona Ctrl+C para detener${NC}"
echo ""

# Start dev server with dynamic port
PORT=$NEXT_PORT npm run dev

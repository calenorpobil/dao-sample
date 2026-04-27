#!/bin/bash

# Script para deploy local automático
# Asegúrate de tener Anvil corriendo en otra terminal: anvil

echo "🚀 DAO Voting Platform - Local Deployment"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Anvil is running
echo "📡 Verificando Anvil..."
if ! curl -s http://127.0.0.1:8545 > /dev/null; then
    echo -e "${RED}❌ Anvil no está corriendo${NC}"
    echo "Por favor inicia Anvil en otra terminal: anvil"
    exit 1
fi
echo -e "${GREEN}✓ Anvil corriendo${NC}"
echo ""

# Default Anvil account
ANVIL_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ANVIL_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Deploy contracts
echo "📝 Deployando contratos..."
cd sc

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creando sc/.env..."
    cat > .env << EOF
PRIVATE_KEY=$ANVIL_PRIVATE_KEY
RPC_URL=http://127.0.0.1:8545
MINIMUM_BALANCE=100000000000000000
EOF
fi

# Build
echo "Compilando contratos..."
forge build --silent

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error compilando contratos${NC}"
    exit 1
fi

# Deploy
echo "Ejecutando deployment..."
DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol:DeployScript \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    --private-key $ANVIL_PRIVATE_KEY 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error en deployment${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Extract addresses from deployment output
FORWARDER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "MinimalForwarder deployed at:" | awk '{print $4}')
DAO_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "DAOVoting deployed at:" | awk '{print $4}')

if [ -z "$FORWARDER_ADDRESS" ] || [ -z "$DAO_ADDRESS" ]; then
    echo -e "${RED}❌ No se pudieron extraer las direcciones${NC}"
    echo "Output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Contratos deployados${NC}"
echo "  MinimalForwarder: $FORWARDER_ADDRESS"
echo "  DAOVoting: $DAO_ADDRESS"
echo ""

# Generate ABIs
echo "📋 Generando ABIs..."
cd ..
jq -r '.abi' sc/out/DAOVoting.sol/DAOVoting.json > web/src/lib/DAOVoting.abi.json
jq -r '.abi' sc/out/MinimalForwarder.sol/MinimalForwarder.json > web/src/lib/MinimalForwarder.abi.json
echo -e "${GREEN}✓ ABIs generados${NC}"
echo ""

# Configure web .env.local
echo "⚙️  Configurando web/.env.local..."
cd web

cat > .env.local << EOF
# Smart Contract Addresses (Public)
NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=$DAO_ADDRESS
NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=$FORWARDER_ADDRESS

# Relayer Configuration (Private - Server Side Only)
RELAYER_PRIVATE_KEY=$ANVIL_PRIVATE_KEY
RELAYER_ADDRESS=$ANVIL_ADDRESS

# Blockchain RPC URL
RPC_URL=http://127.0.0.1:8545
EOF

echo -e "${GREEN}✓ Configuración completada${NC}"
echo ""

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependencias de npm..."
    npm install
    echo -e "${GREEN}✓ Dependencias instaladas${NC}"
    echo ""
fi

echo -e "${GREEN}=========================================="
echo "✅ Deployment completado exitosamente"
echo "==========================================${NC}"
echo ""
echo "📝 Información de Deployment:"
echo "  MinimalForwarder: $FORWARDER_ADDRESS"
echo "  DAOVoting:       $DAO_ADDRESS"
echo "  Relayer:         $ANVIL_ADDRESS"
echo ""
echo "🚀 Próximos pasos:"
echo "  1. Ejecuta: cd web && npm run dev"
echo "  2. Abre: http://localhost:3000"
echo "  3. Configura MetaMask:"
echo "     - Network: Localhost"
echo "     - RPC: http://127.0.0.1:8545"
echo "     - Chain ID: 31337"
echo "  4. Importa una cuenta de Anvil (usa una diferente a la del relayer)"
echo "  "
echo "  5. Ejecuta el daemon: "
echo "     - cd web/app/api/daemon && npm run daemon"
echo ""


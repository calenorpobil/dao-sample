#!/bin/bash

# Script para verificar que todo está configurado correctamente

echo "🔍 DAO Voting Platform - Setup Check"
echo "====================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check Anvil
echo -n "📡 Checking Anvil... "
if curl -s http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "   → Start with: anvil"
    ERRORS=$((ERRORS + 1))
fi

# Check sc/.env
echo -n "📄 Checking sc/.env... "
if [ -f "sc/.env" ]; then
    echo -e "${GREEN}✓ Exists${NC}"

    if grep -q "PRIVATE_KEY=" sc/.env && [ "$(grep PRIVATE_KEY= sc/.env | cut -d= -f2)" != "" ]; then
        echo -e "   ${GREEN}✓ PRIVATE_KEY configured${NC}"
    else
        echo -e "   ${RED}✗ PRIVATE_KEY missing or empty${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "   → Create from: cp sc/.env.example sc/.env"
    ERRORS=$((ERRORS + 1))
fi

# Check web/.env.local
echo -n "📄 Checking web/.env.local... "
if [ -f "web/.env.local" ]; then
    echo -e "${GREEN}✓ Exists${NC}"

    # Check DAO address
    if grep -q "NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=" web/.env.local; then
        DAO_ADDR=$(grep NEXT_PUBLIC_DAO_CONTRACT_ADDRESS= web/.env.local | cut -d= -f2)
        if [ "$DAO_ADDR" != "" ] && [ "$DAO_ADDR" != "0x..." ]; then
            echo -e "   ${GREEN}✓ DAO_CONTRACT_ADDRESS configured: $DAO_ADDR${NC}"
        else
            echo -e "   ${RED}✗ DAO_CONTRACT_ADDRESS not configured${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "   ${RED}✗ DAO_CONTRACT_ADDRESS missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    # Check Forwarder address
    if grep -q "NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=" web/.env.local; then
        FWD_ADDR=$(grep NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS= web/.env.local | cut -d= -f2)
        if [ "$FWD_ADDR" != "" ] && [ "$FWD_ADDR" != "0x..." ]; then
            echo -e "   ${GREEN}✓ FORWARDER_CONTRACT_ADDRESS configured: $FWD_ADDR${NC}"
        else
            echo -e "   ${RED}✗ FORWARDER_CONTRACT_ADDRESS not configured${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "   ${RED}✗ FORWARDER_CONTRACT_ADDRESS missing${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    # Check relayer private key
    if grep -q "RELAYER_PRIVATE_KEY=" web/.env.local && [ "$(grep RELAYER_PRIVATE_KEY= web/.env.local | cut -d= -f2)" != "" ]; then
        echo -e "   ${GREEN}✓ RELAYER_PRIVATE_KEY configured${NC}"
    else
        echo -e "   ${RED}✗ RELAYER_PRIVATE_KEY missing or empty${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "   → Run deployment script: ./deploy-local.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check contracts are compiled
echo -n "🔨 Checking contracts... "
if [ -d "sc/out" ] && [ -f "sc/out/DAOVoting.sol/DAOVoting.json" ]; then
    echo -e "${GREEN}✓ Compiled${NC}"
else
    echo -e "${RED}✗ Not compiled${NC}"
    echo "   → Run: cd sc && forge build"
    ERRORS=$((ERRORS + 1))
fi

# Check ABIs
echo -n "📋 Checking ABIs... "
ABI_ERRORS=0
if [ -f "web/src/lib/DAOVoting.abi.json" ]; then
    echo -e "${GREEN}✓ DAOVoting.abi.json exists${NC}"
else
    echo -e "${RED}✗ DAOVoting.abi.json missing${NC}"
    ABI_ERRORS=$((ABI_ERRORS + 1))
    ERRORS=$((ERRORS + 1))
fi

if [ -f "web/src/lib/MinimalForwarder.abi.json" ]; then
    echo -e "   ${GREEN}✓ MinimalForwarder.abi.json exists${NC}"
else
    echo -e "   ${RED}✗ MinimalForwarder.abi.json missing${NC}"
    ABI_ERRORS=$((ABI_ERRORS + 1))
    ERRORS=$((ERRORS + 1))
fi

if [ $ABI_ERRORS -gt 0 ]; then
    echo "   → Generate ABIs: run ./deploy-local.sh or manually:"
    echo "     cd sc"
    echo "     jq -r '.abi' out/DAOVoting.sol/DAOVoting.json > ../web/src/lib/DAOVoting.abi.json"
    echo "     jq -r '.abi' out/MinimalForwarder.sol/MinimalForwarder.json > ../web/src/lib/MinimalForwarder.abi.json"
fi

# Check node_modules
echo -n "📦 Checking dependencies... "
if [ -d "web/node_modules" ]; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${YELLOW}⚠ Not installed${NC}"
    echo "   → Run: cd web && npm install"
fi

echo ""
echo "====================================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "🚀 Ready to run:"
    echo "   cd web && npm run dev"
    echo ""
    echo "Then open: http://localhost:3000"
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    echo ""
    echo -e "${YELLOW}Quick fix:${NC}"
    echo "   1. Make sure Anvil is running: anvil"
    echo "   2. Run deployment script: ./deploy-local.sh"
    echo "   3. Start web app: cd web && npm run dev"
    echo ""
    echo "See TROUBLESHOOTING.md for more help"
    exit 1
fi

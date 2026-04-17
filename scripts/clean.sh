#!/bin/bash

# Limpia artifacts de build, cache y dependencias

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${YELLOW}🗑️  Limpiando proyecto...${NC}"
echo ""

# Clean smart contracts
echo -n "  sc/out/... "
rm -rf "$PROJECT_ROOT/sc/out" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "  sc/cache/... "
rm -rf "$PROJECT_ROOT/sc/cache" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "  sc/broadcast/... "
rm -rf "$PROJECT_ROOT/sc/broadcast" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

# Clean web dependencies
echo -n "  web/node_modules/... "
rm -rf "$PROJECT_ROOT/web/node_modules" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "  web/.next/... "
rm -rf "$PROJECT_ROOT/web/.next" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "  web/.env.local... "
rm -f "$PROJECT_ROOT/web/.env.local" 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo ""
echo -e "${GREEN}✅ Limpieza completa${NC}"
echo ""
echo -e "${YELLOW}Próximo paso: ./scripts/dev.sh${NC}"

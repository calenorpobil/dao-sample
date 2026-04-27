# DAO Voting Application

Una aplicación full-stack de votación DAO con soporte para transacciones sin gas (meta-transacciones vía EIP-2771).

## 📋 Descripción General

Este proyecto implementa un sistema de votación descentralizado donde los usuarios pueden:
- **Financiar el DAO**: Depositar ETH en el contrato
- **Crear propuestas**: Usuarios con ≥10% del balance del DAO pueden crear nuevas propuestas
- **Votar sin gas**: Usar meta-transacciones para votar sin pagar gas (el relayer paga)
- **Ejecutar propuestas**: Transferencias automáticas cuando se aprueba una propuesta

### Características Principales

✅ **Votación Gasless**: Usuarios votan sin pagar gas mediante EIP-2771  
✅ **Ejecución Automática**: Las propuestas aprobadas se ejecutan automáticamente  
✅ **MetaMask Integration**: Conexión de wallet MetaMask  
✅ **Real-time Updates**: Vista en tiempo real de propuestas y votos  
✅ **Smart Contracts**: Contratos auditados con Foundry  

## 🏗️ Arquitectura del Proyecto

```
dao-sample/
├── sc/                          # Smart Contracts (Foundry)
│   ├── src/
│   │   ├── DAO.sol             # DAO Voting Contract (ERC2771Context)
│   │   ├── MinimalForwarder.sol # EIP-2771 Meta-transaction Relayer
│   │   └── ...
│   ├── test/                   # Tests (*.t.sol)
│   ├── script/                 # Deployment Scripts (*.s.sol)
│   ├── foundry.toml            # Configuración de Foundry
│   └── lib/                    # Dependencias
│
└── web/                         # Frontend (Next.js 15)
    ├── src/
    │   ├── app/                # Next.js App Router pages
    │   ├── app/api/            # API routes (relayer)
    │   ├── components/         # React components
    │   ├── lib/                # Utilities, ABIs, web3 helpers
    │   └── styles/             # Tailwind CSS
    ├── public/                 # Static assets
    ├── .env.local              # Environment variables
    ├── next.config.js          # Next.js configuration
    ├── package.json            # Dependencies
    └── scripts/                
        └── daemon.ts           # Daemon de ejecuciones     
```

### Flujo de Votación (Gasless)

```
1. Usuario crea voto y lo firma OFF-CHAIN (sin gas)
                ↓
2. App envía la firma firmada al Relayer
                ↓
3. Relayer envía meta-transacción a MinimalForwarder (paga gas)
                ↓
4. MinimalForwarder valida la firma y el nonce
                ↓
5. MinimalForwarder hace forward del llamado al DAO contract
                ↓
6. DAO contract (via ERC2771Context) extrae el sender original
                ↓
7. Voto se registra con la dirección original del usuario
```

## 📦 Requisitos Previos

### General
- **Node.js**: v18 o superior
- **npm** o **yarn**
- **Git**

### Smart Contracts (Foundry)
- **Foundry**: [Instalar desde foundry.rs](https://book.getfoundry.sh/getting-started/installation)
- **Solc**: Incluido en Foundry

### Frontend
- **MetaMask Browser Extension**: [Descargar](https://metamask.io/)
- **Local Ethereum Node** (Anvil): Incluido en Foundry

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone <repository-url>
cd dao-sample
```

### 2. Configurar Smart Contracts

```bash
cd sc

# Instalar dependencias de Foundry
forge install

# Compilar contratos
forge build

# Ejecutar tests
forge test
```

### 3. Configurar Frontend

```bash
cd ../web

# Instalar dependencias
npm install
# o
yarn install
```

### 4. Configurar variables de entorno

Crear archivo `.env.local` en la carpeta `web/`:

```env
# Smart Contract Addresses
NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=0x...
NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=0x...

# Relayer Configuration
RELAYER_ADDRESS=0x...
RELAYER_PRIVATE_KEY=0x...

# RPC Provider
NEXT_PUBLIC_RPC_URL=http://localhost:8545
```

## 🛠️ Desarrollo

### Smart Contracts (sc/)

#### Iniciar nodo local (Anvil)

```bash
anvil
```

Esto crea una red local en `http://localhost:8545` con 10 cuentas de prueba.

#### Compilar contratos

```bash
forge build
```

#### Ejecutar tests

```bash
# Todos los tests
forge test

# Con salida detallada (traces para tests que fallan)
forge test -vvv

# Con salida muy detallada (traces para todos los tests)
forge test -vvvv

# Tests de un archivo específico
forge test --match-path test/DAO.t.sol

# Un test específico
forge test --match-test testVote
```

#### Formatear código

```bash
forge fmt
```

#### Generar snapshots de gas

```bash
forge snapshot
```

### Frontend (web/)

#### Iniciar servidor de desarrollo

```bash
npm run dev
```

La aplicación estará disponible en `http://localhost:3000`

#### Construir para producción

```bash
npm run build
```

#### Iniciar servidor de producción

```bash
npm start
```

#### Lint y verificación

```bash
npm run lint
```

## 🚢 Deployment

### Smart Contracts

#### Compilar para producción

```bash
cd sc
forge build --optimize
```

#### Desplegar en testnet (ej: Sepolia)

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast \
  --verify
```

#### Desplegar en mainnet

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://eth-mainnet.infura.io/v3/YOUR_INFURA_KEY \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast \
  --verify
```

### Frontend

#### Opción 1: Vercel (Recomendado)

```bash
# Instalar Vercel CLI
npm i -g vercel

# Deploy
vercel
```

#### Opción 2: Build estático

```bash
npm run build
npm run start
```

Servir el contenido de `.next` con nginx, Apache o similar.

## 📖 Guía de Uso de la Aplicación

### 1. Conectar Wallet

- Hacer click en "Connect Wallet"
- Seleccionar MetaMask
- Confirmar conexión en la extensión de MetaMask
- Se mostrará la dirección conectada y el balance

### 2. Financiar el DAO

- Navegar a "Funding" o similar
- Ingresar cantidad de ETH a depositar
- Confirmar transacción en MetaMask
- Esperar confirmación en blockchain

**⚠️ Requisito**: Debes tener mínimo ETH para votar en propuestas

### 3. Crear una Propuesta

- Navegar a "Create Proposal"
- Ingresar:
  - **Recipient Address**: Dirección que recibirá los fondos
  - **Amount**: Cantidad de ETH a enviar
  - **Voting Deadline**: Fecha/hora límite para votar
- Confirmar transacción
- Propuesta aparecerá en el listado

**⚠️ Requisito**: Debes tener ≥10% del balance total del DAO

### 4. Votar en Propuestas

- Ver listado de propuestas abiertas
- Seleccionar una propuesta
- Elegir voto:
  - ✅ **FOR**: A favor
  - ❌ **AGAINST**: En contra
  - 🤷 **ABSTAIN**: Abstenerse
- Confirmar firma en MetaMask (sin costo de gas)
- El relayer pagará el gas y tu voto se registrará

**⚠️ Requisito**: Solo 1 voto por usuario por propuesta

### 5. Ver Propuestas Ejecutadas

- Las propuestas con:
  - ✅ Plazo de votación finalizado
  - ✅ Votos positivos > votos negativos
  - ✅ Período de espera completado
- Se ejecutarán automáticamente
- Los fondos se transferirán al destinatario

## 🔑 Variables de Entorno

### Smart Contracts (.env)

```env
# Configuración opcional de Foundry
FOUNDRY_PROFILE=default
```

### Frontend (.env.local)

```env
# Contratos Inteligentes
NEXT_PUBLIC_DAO_CONTRACT_ADDRESS=0x...
NEXT_PUBLIC_FORWARDER_CONTRACT_ADDRESS=0x...

# Relayer (Meta-transacciones)
RELAYER_ADDRESS=0x...
RELAYER_PRIVATE_KEY=0x...

# RPC Provider
NEXT_PUBLIC_RPC_URL=http://localhost:8545
NEXT_PUBLIC_CHAIN_ID=1  # 31337 para Anvil, 1 para Mainnet, etc.
```

## 📊 Estructura de Propuestas

Cada propuesta contiene:

```javascript
{
  id: number,              // ID secuencial (1, 2, 3...)
  recipient: address,      // Dirección que recibe los fondos
  amount: uint256,         // Cantidad de ETH
  deadline: uint256,       // Timestamp límite para votar
  positiveVotes: uint256,  // Votos a favor
  negativeVotes: uint256,  // Votos en contra
  abstainVotes: uint256,   // Abstenciones
  executed: bool           // ¿Fue ejecutada?
}
```

## 🔐 Seguridad

### Meta-transacciones (EIP-2771)

- Las transacciones son firmadas off-chain por el usuario
- El relayer valida la firma antes de enviar
- Implementa nonce tracking para prevenir replay attacks
- El usuario NUNCA comparte su private key

### Validación en Smart Contracts

- ✅ Validación de balance mínimo para votar
- ✅ Un voto por usuario por propuesta
- ✅ Validación de deadlines
- ✅ Validación de firma EIP-2771
- ✅ Protección contra reentrancy

## 🐛 Troubleshooting

### "Contract not found" error

```bash
# Asegúrate de que los addresses en .env.local son correctos
# Redeploy los contratos y actualiza los addresses
```

### Anvil no responde

```bash
# Reiniciar Anvil
pkill anvil
anvil

# O especificar puerto diferente
anvil --port 8546
```

### MetaMask no conecta

```bash
# 1. Verificar que Anvil esté corriendo
# 2. Agregar red personalizada en MetaMask:
#    - RPC: http://localhost:8545
#    - Chain ID: 31337
#    - Símbolo: ETH
# 3. Importar cuentas de Anvil usando private keys
```

### Error de gas en meta-transacciones

```bash
# Verificar que el relayer tiene suficiente balance
# Agregar fondos al relayer: anvil (copia el address y envía ETH)
```

## 📚 Recursos

- [Foundry Docs](https://book.getfoundry.sh/)
- [Next.js 15 Documentation](https://nextjs.org/docs)
- [EIP-2771 Spec](https://eips.ethereum.org/EIPS/eip-2771)
- [ethers.js v5 Docs](https://docs.ethers.org/v5/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

## 📝 Licencia

Este proyecto está bajo licencia MIT.

## 👤 Autor

**CarlosBac**  
Email: carlosbac3153@gmail.com

---

**Última actualización**: Abril 2026

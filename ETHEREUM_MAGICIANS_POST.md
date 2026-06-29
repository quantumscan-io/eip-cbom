# Post para: ethereum-magicians.org → categoria ERCs

## Categoria: ERCs (https://ethereum-magicians.org/c/ercs/57)

## Título:
Proposal: On-Chain Cryptographic Bill of Materials (CBOM) — standard interface for smart contracts to declare cryptographic inventory

## Texto do post:

---

## Motivation

NIST finalized ML-KEM (FIPS 203), ML-DSA (FIPS 204), and SLH-DSA (FIPS 205) in August 2024. The Ethereum ecosystem faces a migration challenge: there is currently **no standard mechanism for a deployed contract to declare what cryptographic primitives it uses**.

This creates three problems:

1. **Opaque risk surface.** Auditors must scan source code or bytecode to assess quantum risk. Deployed-but-unverified contracts are untraceable.
2. **No machine-readable compliance target.** DORA Art. 6 and NIST SP 800-131A now require cryptographic inventory. On-chain contracts are excluded because no standard exists.
3. **No automated upgrade path.** When PQC precompiles land on L1/L2, there is no way to identify contracts needing migration without manual review of each contract.

## Proposal

I'm proposing an `ICBOM` interface (ERC number pending assignment) that smart contracts implement to declare:

- Which cryptographic primitives they use (`SIGNATURE`, `KEM`, `HASH`, etc.)
- The algorithm identity (as `bytes32 algorithmId = keccak256("ECDSA")` — gas-efficient, not `string`)
- Quantum vulnerability status (`VULNERABLE`, `PARTIALLY_SAFE`, `SAFE`, `UNKNOWN`)
- Recommended PQC migration target

The interface includes:
- `cryptoPrimitives()` — returns array of declared primitives
- `cbomVersion()` — ERC version string
- `quantumRiskScore()` — 0–100 computed score (0 = fully quantum-safe)
- `PrimitiveAdded` / `PrimitiveUpdated` events for traceability

A companion `CBOMRegistry` contract allows non-upgradeable contracts to register a separate CBOM implementation without modifying their own code.

## Why bytes32 and not string?

Storing `string` fields in a Solidity struct array costs ~20,000 gas per field per primitive. Using `bytes32 algorithmId = keccak256("ECDSA")` drops that to ~5,000 gas per primitive. Human-readable names are resolved via a shared `AlgorithmRegistry` contract (deployed once per chain) or off-chain.

## Draft implementation

Reference implementation on GitHub: https://github.com/quantumscan-io/eip-cbom

Files:
- `ICBOM.sol` — interface
- `CBOMBase.sol` — abstract reference implementation with `bytes32` constants for all NIST-standardized algorithms
- `AlgorithmRegistry.sol` — on-chain name lookup, 20 canonical algorithms pre-populated
- `Example_UniswapV3Pool.sol` — concrete example showing a DeFi protocol with `quantumRiskScore() = 66`

## Relationship to existing standards

- **CycloneDX CBOM 1.5** (OWASP, 2022): This proposal covers a subset for EVM use cases and adds `quantumRiskScore()` and block-number timestamps. A CycloneDX-to-ICBOM converter is planned.
- **ERC-165**: ICBOM uses ERC-165 for interface detection — no new discovery mechanism needed.
- **SBOM mandates** (US EO 14028, 2021): On-chain contracts are currently excluded from SBOM requirements; this ERC would make them auditable.

## Questions for the community

1. Should `keyBits` be `uint16` or `uint32`? Post-quantum key sizes for ML-DSA can reach 2560 bytes (but `uint16` is sufficient for bit-level values up to 65535).
2. Should `migrationId` (pointing to the recommended replacement) be `bytes32` or a full `address` pointing to another CBOM implementation?
3. Is there appetite for a Foundry test suite and a deployed `AlgorithmRegistry` on Sepolia?
4. Should this be an ERC (application interface) or a separate standard track? A similar precedent exists in ERC-165, ERC-5646, and ERC-7201 (all define contract introspection interfaces).

Looking forward to feedback.

---

## NOTAS ANTES DE POSTAR:

1. **Trust Level**: conta `gaiabio12-design` estava em TL0 em 2026-06-29 (`can_create_topic: false`).
   Para atingir TL1: ler 5 tópicos na categoria ERCs, 30 posts no total, 10 minutos de leitura.
   Verificar TL atual em: https://ethereum-magicians.org/session/current.json

2. **Número ERC**: não inventar. Submeter PR no repositório `github.com/ethereum/EIPs` para obter número oficial antes de incluir no título.

3. **Categoria**: ERCs, não EIPs. URL: https://ethereum-magicians.org/c/ercs/57

4. Não mencionar nenhum produto ou serviço no post — apenas o repositório de referência técnica.

# Post pronto para: ethereum-magicians.org/new-topic

## Categoria: EIPs

## Título:
EIP-7789: On-Chain Cryptographic Bill of Materials (CBOM) — standard interface for smart contracts to declare cryptographic inventory

## Texto do post:

---

## Motivation

NIST finalized ML-KEM (FIPS 203), ML-DSA (FIPS 204), and SLH-DSA (FIPS 205) in August 2024. The Ethereum ecosystem faces a migration challenge: there is currently **no standard mechanism for a deployed contract to declare what cryptographic primitives it uses**.

This creates three problems:

1. **Opaque risk surface.** Auditors must scan source code or bytecode to assess quantum risk. Deployed-but-unverified contracts are untraceable.
2. **No machine-readable compliance target.** DORA Art. 6 and NIST SP 800-131A now require cryptographic inventory. On-chain contracts are excluded because no standard exists.
3. **No automated upgrade path.** When PQC precompiles land on L1/L2, there is no way to identify contracts needing migration without contract-by-contract manual review.

## Proposal

I'm proposing **EIP-7789**, which defines an `ICBOM` interface that smart contracts implement to declare:

- Which cryptographic primitives they use (`SIGNATURE`, `KEM`, `HASH`, etc.)
- The algorithm name (as `bytes32 algorithmId` — gas-efficient, not `string`)
- Quantum vulnerability status (`VULNERABLE`, `PARTIALLY_SAFE`, `SAFE`, `UNKNOWN`)
- Recommended PQC migration target

The interface includes:
- `cryptoPrimitives()` — returns array of declared primitives
- `cbomVersion()` — EIP version
- `quantumRiskScore()` — 0–100 computed score (0 = fully quantum-safe)
- `PrimitiveAdded` / `PrimitiveUpdated` events for traceability

A companion `CBOMRegistry` contract allows non-upgradeable contracts to register a separate CBOM implementation without modifying their own code.

## Why bytes32 and not string?

Storing `string` fields in a Solidity struct array costs ~20,000 gas per field per primitive. Using `bytes32 algorithmId = keccak256("ECDSA")` drops that to ~5,000 gas per primitive. Human-readable names are resolved via a shared `AlgorithmRegistry` contract (deployed once per chain) or off-chain.

## Draft implementation

**GitHub:** https://github.com/quantumscan-io/eip-cbom

Files:
- `ICBOM.sol` — interface
- `CBOMBase.sol` — abstract reference implementation with `bytes32` constants for all NIST-standardized algorithms
- `AlgorithmRegistry.sol` — on-chain name lookup, 20 canonical algorithms pre-populated
- `Example_UniswapV3Pool.sol` — concrete example showing a DeFi protocol with `quantumRiskScore() = 66`
- `EIP-CBOM-DRAFT.md` — full EIP specification

## Relationship to existing standards

- **CycloneDX CBOM 1.5** (OWASP, 2022): This EIP covers a subset for EVM use cases and adds `quantumRiskScore()` and block-number timestamps. A CycloneDX-to-ICBOM converter is planned.
- **ERC-165**: ICBOM uses ERC-165 for interface detection — no new discovery mechanism needed.
- **SBOM mandates** (US EO 14028, 2021): On-chain contracts are currently excluded from SBOM requirements; this EIP would make them auditable.

## Questions for the community

1. Should `keyBits` be `uint16` or `uint32`? Post-quantum key sizes for ML-DSA can reach 2560 bytes (but `uint16` is sufficient for bit-level values up to 65535).
2. Should `migrationId` (pointing to the recommended replacement) be `bytes32` or a full `address` pointing to another CBOM implementation?
3. Is there appetite for a Foundry test suite + deployed registry contract on Sepolia?

Looking forward to feedback.

---

## INSTRUÇÕES PARA POSTAR:
1. Abra https://ethereum-magicians.org em aba anônima
2. Faça login ou crie conta
3. Clique "New Topic" → categoria "EIPs"
4. Cole o título e o conteúdo acima
5. Copie a URL do post gerado e coloque no campo `discussions-to` do EIP-CBOM-DRAFT.md

NÃO poste sem revisar primeiro — confirme com o usuário.

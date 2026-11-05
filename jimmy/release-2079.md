Mainnet relic 2079: blocks 17,031,168 to 17,039,359, the Shapella relic. Sealed from the GraphOps archive RPC by `shadow seal --source rpc` (RFC-0004).

**Check this first:** `b3sum manifest.json` must print

```
19397d56a8c6f9a8da49b45305dd9818b6efd0e5ead0ca721ed065c1f8d1c52f
```

Pact root `a904d6d7821cf9faa4ce008c6d01bf49b5f9d376aa370169778fc6cb9c718115`.

| Table | Rows | Bytes |
|---|---:|---:|
| headers | 8,192 | 3,921,712 |
| transactions | 1,316,626 | 1,215,035,091 |
| receipts | 1,316,626 | 77,285,215 |
| logs | 2,537,898 | 106,037,969 |
| withdrawals | 71,741 | 389,503 |

Also on R2: `https://pub-bc282d5016f242a783a6c28cbcd4401a.r2.dev/legacy/v1/1/registry.json`.

**What `solo clean --files` checked, and passed:** file sizes and BLAKE3, Parquet footer counts, schema, row order and content hashes for all five tables, header coverage, parent links and manifest boundaries, header hashes rebuilt through Prague, transaction, receipt and withdrawal trie roots, receipt and header blooms, receipt gas accounting, log/transaction/receipt links. The full report is `clean-2079.txt`.

**What it did not check:** consensus rules and the fork schedule, sender recovery, fees and other derived fields, completeness against the canonical chain, finality, and any checkpoint anchor. Consistency is not chain trust.

**This is a detached pact start** (RFC-0001 §8.4.1). It has no sealed predecessor, so its link to genesis is not established, and the cleaner says so. Re-sealing it with a real predecessor later changes the manifest hash and pact root, not the table content hashes.

The Shadow also checked its own input at fetch time: every served header rebuilt to its hash, every transaction envelope rebuilt from fields to its hash, every recovered sender matched the served `from`. A reader cannot repeat those checks without the journal, so they are a claim about the fetch, not about these files.

Pre-release because `pete/rpc-journal` is not merged.

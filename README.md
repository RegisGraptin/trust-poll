
Zama bounty
https://github.com/zama-ai/bounty-program/issues/144


## Problem 

Many companies offer systems for polling and benchmarking — such as opinion polls, salary benchmarks, or healthcare surveys. However, these solutions typically require users (both individuals and corporations) to send their data in plaintext, relying on a third party to manage sensitive information securely.

Fully homomorphic encryption (FHE) offers a trustless solution by allowing computations on encrypted data. Using FHE, we can create polling and benchmarking applications without exposing the underlying data.

## Actors 

- Organizer: Defines the on-chain data model, such as the types of data to collect and the way the data is aggregated, while maintaining respondent privacy.
- Respondents: Individuals or organizations who submit their responses and encrypt the data using FHE.
- Analysts: Use the encrypted data, such as compute or access aggregated statistics drawn from the encrypted on-chain dataset containing responses from different respondents.


## Example 1 - On-chain opinion pool

An organizer wants to collect opinions on a specific question (e.g., “Are you in favor of XXXX?”) and also gather demographic information such as gender, geography, or age.

Analysts could then view aggregated results, for example, the breakdown of votes from men over 45.

At no point would any individual’s raw response be visible in plaintext.





References 

https://www.zama.ai/post/encrypted-onchain-voting-using-zk-and-fhe-with-zama-fhevm
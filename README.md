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

## Polling vs Benchmark

In Polling scenario, we want to commpute the sum of the choices, whearas in benchmark we want to compute the average.

## Polling structure

Let's first defined the polling. We will describe a polling as a sentence where a set a users need to answer to it. For that, they will have access to a list of know answer and pick one of them.

A simple polling could be:
Are you in favour of selling this table?
Yes / No

A more complex one could be to add other solutions as "No opinion", which do not really complexify the issue.

However, the multiple choice can complexify it.
By allowing the user this time to select multiple value.

Where do want to go on vacation?
France / Italia / Vietnam

We can differenciate those two pollings, even if we have the same result, the condition will not be the same.

=> Question check

## Business opportunity

An analyst will be interesting to have a view on the data as it is king.
In order to get it, he will be in charge to pay an additional fees to remunerate the other who has share they private data.

# Type of voting

- Anyone can vote
- Whitelisted members

# Reveal vote

- In all the cases we will add a end time vote. It can be the largest one possible.
- Or can be consider finish if all the participant have voted.

- Threshold parameter allow the possibility to visualize the current vote. But will not consider the survey as finished.

---

Votes can be reveal on two things

- Either we have reach the total number of threshold (mod 10)
- Either all the expected participants have voted
- End of voting time

- Wait end of time or all participants has voted

=> Defined the ending condition, when does the vote is seatled.

## References

https://www.zama.ai/post/encrypted-onchain-voting-using-zk-and-fhe-with-zama-fhevm

## Questions:

- "Pre-computation of statistics: Aggregate data in batches to minimize expensive on-chain TFHE operations."

## Design architecture

One potential design approach:

- create factory contract, to easilly deploy new one
- Manage all the logic in a single smart contract
- Split the polling and benchmark logic in two separate contract

If we are thinking about a business perspective, a factory pattern we kind of loose track of the users, by becoming more complex to fetch the user info

## UI Aspect

On the first section, we need to see the user vote, to let them know how they can do it, while providing metadata.
For example, on the salary, I want to have an idea of the sector, maybe the age...
This need to be submitted while voting.

## Vote creation - param needed

- Question

- Vote type (benchmark or polling 2 answer)
  => One int to store the data result

- Is whitelisted?
- If yes --> merkel tree root hash
- If no, put warning attack

- End time for voting? (0 -> No else Yes)

- Participant threshold (for reveal)
  => Need to think of edge cases. If 2 but 3 participants, last one can be leaked!
  => Be careful of the end time for voting
  => Reveal - no end time => threshold count
  => Reveal - end time - end time + threshold with constraint!

- Metadata
- Metadata & constraint (v2)

### Info during process

- Number of participants
-

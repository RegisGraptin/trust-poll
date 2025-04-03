<a id="readme-top"></a>

<br />
<div align="center">
  <a href="#">
    <img src="./logo.png" alt="Logo" width="250" height="250">
  </a>

<h3 align="center">Private Polling & Benchmark Protocol</h3>
<p align="center" style="font-style: italic; font-size: 1.2em;">Built during <a href="https://github.com/zama-ai/bounty-program/issues/144">ZAMA Bounty Program - Season 8</a></p>
  <p align="center">
    A trustless on-chain solution for privacy-preserving surveys and benchmarking using FHE.
    <br />
    <br />
    <a href="#">Code</a>
    &middot;
    <a href="#">View Demo</a>
    &middot;
    <a href="#">Video Presentation</a>
  </p>
</div>

## About The Project

Participating in traditional polling or benchmarking forces you to surrender private data to third parties—a fragile system where your sensitive information becomes their liability. What if your data could contribute to collective insights without ever being exposed, even during analysis?

This is the promise of PrivatePolls, a propose private polling protocol using Fully Homomorphic Encryption (FHE). This protocol empowers organizations and individuals to conduct encrypted opinion polls (e.g., “Should our DAO fund AI startups?”) and benchmarks (e.g., anonymized salary comparisons) without ever exposing raw data.

## Features

By leveraging Zama’s FHEVM, PrivatePolls enables:

- Encrypted submissions: Respondents submit data that remains cryptographically sealed, even during computation.

- Threshold-based insights: Aggregate results are revealed only when predefined privacy thresholds (e.g., 50+ participants) are met, preventing individual data leaks.

- Role-based access: Organizers define survey parameters, analysts pay to query encrypted datasets, and participants retain full ownership of their sensitive inputs.

- Built for blockchain-native governance, salary transparency, and healthcare surveys. PrivatePolls replaces fragile trust models with mathematically enforced privacy.

## Design architecture

Our protocol uses a single smart contract to manage both private polling and benchmarking. This design is mainly motivated by a business perspective allowing us to manage more easily reward mechanisms for the participants. See more in business opportunity section. However, this does not impact the logic of the polling/benchmark as in both cases, we are going to count the number of entries and the total sum of the votes, allowing us to do the average or the mean depending of the type of entry we are requested.

PrivatePolls can be decomposed in two phases. The voting time and the analyse. During the voting time, users can submit new entry to the survey. Once the vote is finished, and we have enough participants according to the threshold parameter, the survey result is decrypted. Then the analyse phase is unlock allowing anyone one to request new analyse on the metadata.

## Create a new survey

When defining a new survey, the organizer will be in charge of multiple parameters.

To create a new survey, you can call the `createSurvey` function from the solidity smart contract. We expect to have the following data in the parameter:

```solidity
struct SurveyParams {
    string surveyPrompt;            // The survey question
    SurveyType surveyType;          // The type of survey (POLLING, BENCHMARK)
    bool isWhitelisted;             // Indicates if the survey is restricted to a whitelisted users
    bytes32 whitelistRootHash;      // Merkle root hash for allowlist verification (if restricted)
    uint256 surveyEndTime;          // UNIX timestamp when survey closes
    uint256 minResponseThreshold;   // Minimum number of responses required before analysis/reveal
    MetadataType[] metadataTypes;   // List of metadata requirements from participants
    Filter[][] constraints;         // Constraints defining a valid metadata
}
```

Notice, that the `whitelistRootHash` is optional depending if you want to have a whitelisted mechanism defined by the `isWhitelisted` variable. (Learn more on how to defined this parameter in the "Whitelist mechanism" section)

When creating a new survey, we expect to have a threshold defined, allowing us to know on how many data we need to have in order to validate the survey and to do analyses afterward.

Finally, you can defined a list of metadata types allowing you to collect those encrypted informtation from the user. You have also the possibility to include some constraint on it, depending on the data you want to collect.

Notice that even if we are providing tools for encrypted survey, you may need to still have consideration on privacy preserving system.

//FIXME: Even if we are providing tools allowing user to defined a good private preserving survey, it will be responsible on the data and constraint definition.

```typescript
// Example in typescript

const surveyParams = {
  surveyPrompt: "Are you in favor of privacy?",
  surveyType: SurveyType.POLLING,
  isWhitelisted: false,
  whitelistRootHash: new Uint8Array(32),
  surveyEndTime: Math.floor(Date.now() / 1000),
  minResponseThreshold: 4,
  metadataTypes: [MetadataType.UINT256, MetadataType.BOOLEAN], // [Age, Gender]
  constraints: [
    // Age constraint
    [
      {
        verifier: FilterOperator.LargerThan,
        value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [10]),
      },
      {
        verifier: FilterOperator.SmallerThan,
        value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [110]),
      },
    ],
    // Gender constraint
    [],
  ],
};

const transaction = await this.survey.createSurvey(surveyParams);
await transaction.wait();
```

### Privacy consideration

- What would be a good threshold?

> => Need to think of edge cases. If 2 but 3 participants, last one can be leaked!
> We need more than 3 for the threshold and recomand more if possible
> For the user also the same recommanded

// TODO:: Add the possibility to add contraint, allowing us to validate or not the user metadata. Notice, that it is the responsability to determined the metadata limit.
// For instance, we expect for the age a value between 0 and 110. However, if a choice of 20-30, can restraint the vote, and directly target user privacy.

#### Threshold parameter

todo

#### Metadata choice

When defining the metadata, we need to take into consideration the group we are going to analyse. For instance, if we are reliyng on some distinct attribute, it can potentially leaks the vote data, as we could potentially guess the value.

This is why a note shoud be done on the metadata selected and the threshold selected.

FIXME: When reveal we also need ot think about the opposite request. As an example:
I can select the age above 60, which represent 1 vote. When cehcking before the gatway
I will say this requets is not valid, as it will leak the result.
However, the opposite is also true, meaning that if I request the vote bellow 60
I will get all the votes. Then I can simply compare the polling result with the one
obtain. Which will leak the current user!

### Metadata customization

By our approach, we can add any kind of metadata and filter of operation.

On the operation side, we are expected to have a bytes, meaning that the decryption can be done as we want.

However, the multiple choice can complexify it.
By allowing the user this time to select multiple value.

Where do want to go on vacation?
France / Italia / Vietnam

We can differenciate those two pollings, even if we have the same result, the condition will not be the same.

### Whitelist mechanism

In our protocol, we also allow the possibility to create a whitelist mechanism.

Polling and Benchmark can be subject to whitelisted mechanism. To handle it, our protocol will store the root hash of the Merkle Tree. When a user want to submit an entry, he will need to provide the proving path of the Merkle Tree to validate it.

A survey can also be whitelisted. To limit the on-chain computation, we are relying on the Merkle-Tree from the OpenZeppelin package (https://github.com/OpenZeppelin/merkle-tree)

### Reveal data

To reveal the data, the survey has to be terminated, meaning that we have reach the end time from it or in the case of a whitelisted one, all the participants have sumbitted an entry.

<!-- TODO: display typescritp code on how to use it -->

## Analyse the data

## Query

When doing an analyse the query parameter are past in public, meaning that all people can see the user query.

Design choice of the customization with as much fitler possible

The analyst will have the possibiltiy to defined as much filters he wants for all the potential metadata. The customization can be relly precise. However the result will be only reveal if we have a matching threshold number.
For instance, if the user want to know how much people have voted in favor of the survey where they live in France, have 30 years old, have one dog... It will only be reveal if we have at least 30 results.

Notice that the opposit is also true. The negative version is also not valid, as it will show the opposite and can be reveal when comapring to the totla one.

> With full customization we are limited in the optimization structure we can proposed.
> Limitation is the computation over all the data again and again.

> - "Pre-computation of statistics: Aggregate data in batches to minimize expensive on-chain TFHE operations."

### Validate a query

Once the query isfully executed over all the data, we need to verify that the data does not leak any information. This verification step is done by taking into account the number of selected votes. If we do not reached the expected threshold or if

> Say that 0 -> threshold or max - threshold -> max

To handle this logic, we need to have a double verification. First we need the gateway to send a smart

=> Participant number equals 0

## Business opportunity

An analyst will be interesting to have a view on the data as it is king.
In order to get it, he will be in charge to pay an additional fees to remunerate the other who has share they private data.

# Business Opportunity

And another one could be add the possibility to "sell" the request.
Indeed, executing over all the date are kind of costly. Thus, it represents
a certain cost to run and execute. So, one potential idea could be to have a
public query but need to buy the output to avoid running again the same query.

We can have then two kinds of market
First one will be to execute the query and thus add the possibility to pay back
the users.
Or the second cases could be to pay the executed query and give a fee to the users.
TODO: Add those point in the README:Business idea section
=> Need to think to have a ready for prod product, and maybe a DAO to pay back this
TOken allocation to contributed users? Need to brainstorm about it!

> Possibiltiy to create theshold area allowing decryption/reveal of the data from the vote or the analysis
> ==> BUT this leads to a potential single point of failure where we do not have enough participants it locks the smart contract. As we will not be able to decypher it without revealing the user vote.

TODO: Possibility to have encrypted query
// We could push the encryption boundaries further, by encrypting the query too
// Or we want transparency on the user data requested?

## Roadmap

- [] At the moment we do not handle complex polling data. Meaning that we only have two choice at the moment (true/false). An improvment could be to add other possibilities allowing more customization. Also, another level of improvment will be to manage multiple user choice. But thought those features, we will need to reconsider the design as it is polling feature and not a benchark one.

- [] Possibility to have an interactive approach as reaviling the polling while pending result.

  > Note: we try to first think on an interactive approach, allowing people to potentially reveal the vote while running and also doing some analysis while the polling is running. But this brings some limitation as a user could ask to reveal the data, just before the last person want to submit it, meaning that we will not take his vote into account.

- Another approach could be to have encrypted query allowing more private query purpose
  Could be interesting to some user cases, when you do not want to lose advantage from others

- Disallow precise metadata combo. It will kind of limit the analysis, but we may want to avoid specific combinaison of metadata.
  => Could be handle if we are dealing with a single one but still need to keep privacy, which is the difficult part.

- Create incentive mechanism when creating a new polling - and this one is validated, meaning at some point user validated and confirm it

--> Need to think aobut potential exploit as bot created multiple survey, then voted for each of them to get some tokens.

--> Think about the remuneration

--> Human proof to avodi bot

--> How to check user metadata consistency? Can we kind of centralize user metadata information?

## Avoid using encrypted indexes

Currently, when we want to filter on some data, we need to iterate over all of them to be able to preserve homomorphic encryption.
However, this is gas intensive and should be avoid.

https://docs.zama.ai/fhevm/smart-contract/loop#avoid-using-encrypted-indexes

To handle it, one possibility will be to know, beforehand, which fields we want to aggregate on. For instance, we could see of a tree structure.
However, this can potentially leads to some leak.
For instance, if we have a metadata on the age. We can try to guess the tree structure data, by providing encrypted age that could indicate the path of the tree.

## Attack example when interactive reveal

=> Handle!

1. In a case of a whitelist, we can potentially block the vote. As an example, at any moment, we can decypher the vote in order to have a current view on the voting. However, in case we have a whitelitsed sets, the set of participants is finite. Meaning that if we are requesting to decypher the data when we have one last participants, we can induct his vote, which breaks the privacy design.

=> By the current design, it is not possible to handle it correctly. Some can just start multiple requests at the same time, with doublon and wait for a user until he traps it.

2. Potential leak on repeated queries between vote. For instance, let's say we already have 20 participants that have voted. We would like to analyse the result based on the age. Let's say now, a new participant vote, now the malicious analyst can again start a new query and check the differences between previous and before. We will not know the direct result, however, we will have an indication on the participant metadata.
   => Design limitation at the moment
   => We can go furher, now let's say someone is determined to kind of know your associated metadata. He can decided to let's say try to have an understanding of the data before, by doing a full analyse of the state S. Then, when a new user vote, he can decide to do all the previous analyse that kind of cover the previous dataset, to understand and determine some information about the new vote. This kind of approach is possible for a determined user.
   => Should we also add a theshold parameter here.
   => TODO: add a task to add a parameter for this one

==> Issue: when do we do the analyse. I mean, if we are doing during a vote, could we have an issue on the number of votes?
=> No, as the number of votes will keep increase while the analyse is done.

When we create a query, we are storing when we can reveal it on the expected number of voters. else it will be consider as pending until we have enough votes to not leak the users data.

=> Hande it by a flag indicating if we want to decypher the data, when all the participants have voted or not.

=> Can slo be handle at the initialization by defining rules to the data aggregation.

# Graph section

// TODO: To optimize the verification process query verificaiton

> Subnotes

At initial, we wanted to add the possibility to reveal partially the results. Let's say you have already 50 participants, you may want to have a current view of the polling result. This approach works pretty well, however the composition with the pending analysis and edge cases complexify a lot the implementation, leading to potential leaks. We decided, for a first version, to allow a reveal operation when a survey is done. Meaning in a whitelisted mechanism all the participants have voted or the end time is reach.

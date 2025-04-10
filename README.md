<a id="readme-top"></a>

<br />
<div align="center">
  <a href="#">
    <img src="./logo.jpeg" alt="Logo" width="250" height="250">
  </a>

<h3 align="center">Private Polling & Benchmark Protocol</h3>
<p align="center" style="font-style: italic; font-size: 1.2em;">Built during <a href="https://github.com/zama-ai/bounty-program/issues/144">ZAMA Bounty Program - Season 8</a></p>
  <p align="center">
    A trustless on-chain solution for privacy-preserving surveys and benchmarking using FHE.
    <br />
    <br />
    <a href="https://github.com/RegisGraptin/trust-poll">Code</a>
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

PrivatePolls can be decomposed in two phases. The voting phase and the analyse one. During the voting time, users can submit new entry to the survey. Once the vote is finished, and we have enough participants according to the threshold parameter, the survey result is decrypted. Then the analyse phase is unlock allowing anyone one to request new analyse on the metadata.

## Create a new survey

When creating a new survey, the organizer will be in charge of multiple parameters. To create a new one, you can call the `createSurvey` function from the solidity smart contract. We expect to have the following parameter defined.

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

Finally, you can defined a list of metadata types allowing you to collect those information encrypted from the user. You also have the possibility to include some constraints on it, depending on the data you want to collect.

Finally, note that we are providing a tool to help you creating an encrypted survey. However, you still are responsible to include in your reflection privacy to avoid too much restricted contraints or even, a threshold too small based on your sample.

### TypeScript example

```TypeScript
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

When designing a survey, two critical parameters must be considered to protect participants' privacy:

#### Threshold Parameter

The threshold parameter defines the minimum number of participants required before a survey result can be disclosed. This is a critical parameter that should be adjust based on your population. We requiered at least 3 participants. However, we stronly recommand to increase it to improve the anonymization in your system.

Notice that in a non whitelisted mechanism, nothing disallow a malicious attacker to create multiple addresses and submit multiple entries. It can then impact the result of the survey. This can of behaviour can be eventually managed by providing a proof of humanity but will give a more restriction for voting.

#### Metadata Constraints

Metadata constraints define the parameters that validate or reject user-provided metadata to prevent invalid metadata parameter. It is the responsibility of the survey organizer to determine appropriate limits. Keep in mind that by having too much restricted constraints you may leak the voters as only a portion of them could be able to vote.

Reasonable limits should be consider based on the possible value of the metadata. As an example, for the age value, we can reasonably assume a constraint limit between 0 and 120. If we defined too much restricted constraints, as an age of 20-30, people from Italia... we will filter the participants, which might be the initial though, but on the other hand this can leak the participants behind the address. By restricting the dataset, we are indirectly exposing participant identities.

### Metadata customization

By our approach, we can add and customize metadata and filters. Indeed, an opperation can accept a bytes value, meaning that during the decoding process, you can handle it as you want. To defined a new metadata or filter, you can modify the `IFilter.sol` file and update the core logic yo handle the filter in the `MetadataVerifier` contract.

As an example, we could update our filter mechanism to handle more granuarly categorical values. For instance, be able to handle complex categorical value as the list of countries a person went: "France", "Italia", "Vietnam"...

### Whitelist mechanism

In our protocol, Polling and Benchmark can be subject to whitelisted mechanism. To handle it, our protocol will store the root hash of the Merkle Tree. When a user want to submit an entry, he will need to provide the proving path of the Merkle Tree to validate it. On the Merkle-Tree, we are relying on the OpenZeppelin package (https://github.com/OpenZeppelin/merkle-tree). To defined a new one, you can do:

```TypeScript
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

// ...

// Defined the list of whitelisted address and compute the associated tree
const whitelistedAddresses = [
  [this.signers.alice.address],
  [this.signers.bob.address],
  [this.signers.carol.address],
  [this.signers.dave.address],
];
const tree = StandardMerkleTree.of(whitelistedAddresses, ["address"]);

const surveyParams = {
  ...validSurveyParam,
  isWhitelisted: true,
  whitelistRootHash: tree.root,  // Define the root tree in the survey
};

// ...

// When a user want to proove he is part of a whitelisted tree,
// he needs to generate a proof path based on the original tree.
let whitelistedProof: HexString[] = [];
for (const [i, v] of tree.entries()) {
  if (v[0] === signer.address) {
    whitelistedProof = tree.getProof(i);
    break;
  }
}
```

### Reveal data

To reveal the data, the survey has to be terminated, meaning that we have reach the end time from it or in the case of a whitelisted one, all the participants have sumbitted an entry. Note that, in the case you have defined metadata constraints, you might have to wait an additional delay allowing the Gateway to confirm or not the input user metdata.

To reveal it, you can simply call the solidity `revealResults` function with the id of the survey you want to reveal. Or simply:

```TypeScript
const surveyId = 42;
await this.survey.revealResults(surveyId);
```

Notice that the result will be revealed only if we ave reached the minimal expected threshold. Else, the survey will be consided as invalid. Again, the result might not be reveal directly as we need the Gateway to process it.

## Analyse the data

Once a survey is completed and valid, analyst have the possibility to create custom requests to better understand the data. For that, they will first need to create a query and execute it.

When creating a query, analyst needs to defined public filters that will be used on the encrypted entries. Note that at the moment, the filters are public, but it could be intersting to maybe think about private filters, allowing maybe business opportunities to sell the result of the query or to keep competitive advantages on the query analysed.

On the design implementation, we have decided to focus on the customization, meaning that we do not have restriction on the query done. Thus, a analyst will have the possibiltiy to defined as much filters he wants for all the potential metadata. Although the query can be extremelly precise, it can be reveal only if we have reach the expected threshold.

For instance, if the user want to know how much people have voted in favor of the survey where they live in France, have 30 years old, have one dog... It will only be reveal if we have at least 30 results. Notice that the opposite is also true. The negative version is also not valid, as it will show the opposite and can be reveal when comapring to the totla one.

This desing approach have some restrictions. First, we do not propose aggregation limitation on the metadata filter. It could maybe be an interesting mechanism to protect users, but this can be adapt with a strong thrshold value.
The second limitation will be on the execution cost. Indeed, by having any kind of metadata, we do not have a proper structure alowing us to optimize the execution cost, meaning that for a given query, we need to iterate over all the entries, which can be pretty gas intensive.

### Create a custom Query

To create a query, a analyst will have to wait the survey is completed and valid. Then, he can defined a list of filters for each metadata and call the smart contract to create it.

```TypeScript
// Metadata defined as [MetadataType.UINT256, MetadataType.BOOLEAN] stands for [age, gender]
// Defined a filter to analyse polling result with an age greater than 55
const filters = [
  [
    {
      verifier: 0, // LargerThan
      value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [55]),
    },
  ],
  [],
]

// Create a query by selecting the survey's ID and the filters we want to analyse
await this.survey.createQuery(0, filters);
```

### Execute the Query

As mention before, we need to iterate over all the entries to preserve privacy. However, iterating over all may consume too much gas for a single transaction. To handle it, we can iterate it using batch mechanism. The idea is to use a cursor that is going to iterate over a small subset of the entries, reducing the gas needed for a transaction. However, though this mechanism, we may need to execute multiple transaction allowing us to iterate over all the entries.

In our implementation, we propose two functions, doing exactly the same thing. One helper that is going to iterate over 10 entries, and another customizable.

```TypeScript

// Iterate over 10 entries given the surey ID 0
await this.survey["executeQuery(uint256)"](0);

// Iterate over 100 entries
await this.survey["executeQuery(uint256,uint256)"](0, 100);
```

Once the query is fully executed over all the data, we need to verify that the data does not leak any information. This verification step is done by taking into account the number of selected votes. If we do not reached the expected threshold the query will be consider invalid. To have access to the result, we will need to wait the gateway process to decrypt the expected result.

### Fetch the Analyse result

Once the result of the survey reveal you can fetch the result directly on chain. For that, you can request it by doing:

```TypeScript
const queryId = 0;  // To modify in your case
const queryData = await this.survey.queryData(queryId);
```

To ensure the result is valid and reveal, you will have to verify that the flags `isCompleted` and `isValid` are activated.

## Business opportunity

Data are gold. However, privacy matter. Through our system, we allow the possibility to analyse polling and benchmark in detail, without revealing the user data.

Future development of this can lead to economic incentivize
remuneration mechanism to rewards participant n d

An analyst will be interesting to have a view on the data as it is king.
In order to get it, he will be in charge to pay an additional fees to remunerate the other who has share they private data.

### Reward participants

To inventivize participants, we can reward them each time they are submiting an entry for a polling or a benchark. By doing so, we are reward them to providing accurate data.

Note that flood verification mechanims will need to be set. Indeed, at the moment, in our protocol, no mechanims block if a user submit multiple entries using multiple wallets.

### Sell analyst requested done

Currently analyse request are "free", apart the execution cost. A modification could be to request a payment each time an analyse is done, allowing us to easily rewards participants of the polling.

### Analyse second market

As mention beforehand, the analyse requets needs to be executed and have thus have gas fee. A modification in the protocol can be made to encrypt the result of the survey to only whitelisted member. By doing so, an analyst can get reward by selling a query executed. A fee can be taken and sent to the user, while the other can be taken to the analyst.

THis mechanism can be interesting depending of the number of data. Indeed, as we need to iterate over all the dataset, it might be intersting to propose a cheaper query by selling directly the result. For that a modification in the query mechanism will need to be done, to allow the possibility to have encrypted request result.

### encrypted query

At the moment, the query realized are public, meaning full transparency on the analyse done on the data. It allows the possibility to anyone to see what is going on on the dataset. However, regarding businesses opportunity, it may leak some information and opportunities. A possibility could be to encrypt the query inputs, allowing full confidentiality on the request executed, while preserving confidential metadata of the users. Depending of the philosophie of the protocol, this kind of request can be "tax" higher than traditional one.

Depending if we want full transparency on the network or not.

## Roadmap

> Possibiltiy to create theshold area allowing decryption/reveal of the data from the vote or the analysis
> ==> BUT this leads to a potential single point of failure where we do not have enough participants it locks the smart contract. As we will not be able to decypher it without revealing the user vote.

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

## Attack example when interactive reveal

- A potential attacks could be on metadata restriction. Currently, we allow the possibility when doing a vote to restricted the metadata. Thus, anyone can set a metadata constraint as an age between 20 and 30. However, by doing so, we are putting some indications on the metadata. And if we are considering multiple survey constraint, this can lead to a leak. As an example, if I have two survey on for age above 30 and another less than 32 and that both submit entry are consider valid, then it leaks the user data.
  => This is why, by design, people should remain cautious when submitting data, especially on the threshold parameter and the metadata constraint, as we cannot avoid malicous actors.

# Graph section

## Notes

// TODO: To optimize the verification process query verificaiton

> Subnotes

At initial, we wanted to add the possibility to reveal partially the results. Let's say you have already 50 participants, you may want to have a current view of the polling result. This approach works pretty well, however the composition with the pending analysis and edge cases complexify a lot the implementation, leading to potential leaks. We decided, for a first version, to allow a reveal operation when a survey is done. Meaning in a whitelisted mechanism all the participants have voted or the end time is reach.

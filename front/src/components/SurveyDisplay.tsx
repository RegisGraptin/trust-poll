import {
  MetadataType,
  SurveyData,
  SurveyParams,
  SurveyType,
  useHasVoted,
} from "@/hook/survey";
import { getFHEInstance } from "@/lib/fhe";
import React from "react";
import { useEffect, useState } from "react";
import {
  useAccount,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

import Survey from "@/abi/Survey.json";
import { Address, toHex } from "viem";

enum SurveyState {
  ONGOING,
  TERMINATED, // End of the survey just before having the result
  VALID,
  INVALID,
}

const SurveyDisplay = ({
  surveyId,
  surveyParams,
  surveyData,
}: {
  surveyId: number;
  surveyParams: SurveyParams;
  surveyData: SurveyData;
}) => {
  const { address: userAddress } = useAccount();
  const { data: hasVoted, refetch: refetchHasVoted } = useHasVoted(
    surveyId,
    userAddress
  );
  const [txLoading, setTxLoading] = useState<boolean>(false);

  const [userMetadata, setUserMetadata] = useState<
    (boolean | number | undefined)[]
  >([]);

  const handleMetadataChange = (index: number, value: boolean | number) => {
    setUserMetadata((prev) => {
      const updated = [...prev];
      updated[index] = value;
      return updated;
    });
  };

  const [state, setState] = useState<SurveyState>(SurveyState.TERMINATED);

  const {
    data: hash,
    error,
    writeContract,
    isPending: txIsPending,
  } = useWriteContract();

  const { isLoading, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  const onVote = async (entry: boolean) => {
    setTxLoading(true);

    // Get the FHE instance
    console.log("Retrieve FHE Instance");
    let instance = getFHEInstance();
    if (!instance) {
      console.log("Instance loading...");
      setTxLoading(false);
      return;
    }

    // Encrypt the inputs
    console.log("Encrypt the parameters");
    const input = instance.createEncryptedInput(
      process.env.NEXT_PUBLIC_SURVEY_CONTRACT_ADDRESS!,
      "" + userAddress
    );

    // Add the user entry depending of the selected value
    input.add256(entry ? 1 : 0);

    // Add the metadata
    userMetadata.map((metadata, index) => {
      switch (surveyParams.metadataTypes[index]) {
        case MetadataType.BOOLEAN:
          input.addBool(Boolean(metadata));
          break;
        case MetadataType.UINT256:
          input.add256(Number(metadata));
          break;
        default:
          throw TypeError("Invalid metadata type");
      }
    });
    let encryptedInputs = await input.encrypt();

    // Write the entry to the survey contract
    console.log("Write the entry to the smart contract");
    writeContract({
      address: process.env.NEXT_PUBLIC_SURVEY_CONTRACT_ADDRESS as Address,
      abi: Survey.abi,
      functionName: "submitEntry",
      args: [
        surveyId,
        toHex(encryptedInputs.handles[0]),
        encryptedInputs.handles.slice(1).map((eInput) => toHex(eInput)),
        toHex(encryptedInputs.inputProof),
      ],
    });

    setTxLoading(false);
  };

  useEffect(() => {
    if (isConfirmed) {
      refetchHasVoted(); // We could avoid searching on chain the parameter.
    }
  }, [isConfirmed]);

  useEffect(() => {
    if (surveyData === undefined) return;

    // Know that the survey is completed
    if (surveyData.isCompleted) {
      if (surveyData.isValid) {
        setState(SurveyState.VALID);
      } else {
        setState(SurveyState.INVALID);
      }
      return;
    }

    // Check if we can still vote
    const currentTime = Math.floor(Date.now() / 1000);
    if (currentTime < surveyParams.surveyEndTime) {
      setState(SurveyState.ONGOING);
      return;
    }
  }, [surveyData.isCompleted, surveyParams.surveyEndTime]);

  const getStatusMessage = () => {
    switch (state) {
      case SurveyState.ONGOING:
        return "Ongoing survey";
      case SurveyState.TERMINATED:
        return "Ended survey";
      case SurveyState.VALID:
        return "Survey valid";
      case SurveyState.INVALID:
        return "Survey invalid";
    }
  };

  return (
    <div className="card w-full bg-base-100 shadow-xl border-2 border-primary relative">
      {/* Status Banner */}
      <div className="bg-primary/10 text-primary rounded-t-xl px-4 py-3">
        <div className="w-full text-center">
          <h3 className="font-semibold text-sm">{getStatusMessage()}</h3>
        </div>
      </div>

      {/* Whitelist Tooltip */}
      {surveyParams.isWhitelisted && (
        <div
          className="absolute top-2 right-3 tooltip tooltip-left"
          data-tip="Whitelisted"
        >
          <button className="btn btn-xs btn-circle btn-ghost text-info">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M13 16h-1v-4h-1m1-4h.01M12 2a10 10 0 100 20 10 10 0 000-20z"
              />
            </svg>
          </button>
        </div>
      )}

      <div className="card-body">
        <div className="flex flex-col items-center space-y-2 text-center">
          <h2 className="card-title">{surveyParams.surveyPrompt}</h2>
        </div>

        <div className="px-4 py-3 space-y-2">
          <div className="grid grid-cols-2 gap-2 text-sm">
            <dt className="font-medium text-secondary">Min threshold:</dt>
            <dd className="text-base-content">
              {surveyParams.minResponseThreshold.toString()}
            </dd>
          </div>

          {/* Collect the user metadata */}
          {surveyParams.metadataTypes?.length > 0 && (
            <div className="mt-4 space-y-4">
              <h4 className="font-semibold text-sm text-secondary">
                Your Metadata
              </h4>

              {surveyParams.metadataTypes.map((type, index) => {
                const value = userMetadata[index];

                return (
                  <div
                    key={index}
                    className="grid grid-cols-3 items-center gap-4 mb-3"
                  >
                    <label className="col-span-1 font-medium text-sm text-base-content text-left">
                      {surveyParams.metadataNames[index]}
                    </label>

                    {type === MetadataType.BOOLEAN ? (
                      <select
                        className="select select-bordered select-lg col-span-2 w-full"
                        value={value === undefined ? "" : String(value)}
                        onChange={(e) =>
                          handleMetadataChange(index, e.target.value === "true")
                        }
                        required
                      >
                        <option value="">Select</option>
                        <option value="true">True</option>
                        <option value="false">False</option>
                      </select>
                    ) : (
                      <input
                        type="number"
                        className="input input-bordered input-lg col-span-2 w-full"
                        value={value === undefined ? "" : Number(value)}
                        min="0"
                        onChange={(e) =>
                          handleMetadataChange(index, Number(e.target.value))
                        }
                        required
                      />
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Collect the user entry */}
        <div className="flex flex-col gap-2 mt-4">
          {txLoading && (
            <div className="flex items-center justify-center">
              <div className="w-12 h-12 border-4 border-t-transparent border-blue-500 rounded-full animate-spin"></div>
            </div>
          )}

          {!txLoading &&
            state === SurveyState.ONGOING &&
            surveyParams.surveyType === SurveyType.POLLING && (
              <>
                {!hasVoted ? (
                  <div className="flex gap-4">
                    <button
                      onClick={() => onVote(true)}
                      className="btn btn-success flex-1"
                    >
                      Yes
                    </button>
                    <button
                      onClick={() => onVote(false)}
                      className="btn btn-error flex-1"
                    >
                      No
                    </button>
                  </div>
                ) : (
                  <div className="alert alert-info">
                    You've already voted on this survey
                  </div>
                )}
              </>
            )}

          {!txLoading &&
            state === SurveyState.ONGOING &&
            surveyParams.surveyType === SurveyType.BENCHMARK && (
              <>
                <div>
                  <h2>TODO:</h2>
                </div>
              </>
            )}

          {/* Progress Bar */}
          {state === SurveyState.ONGOING && (
            <div className="mt-6">
              <div className="flex justify-between mb-2">
                <span>{surveyData.currentParticipants}/10 votes collected</span>
                <span className="animate-pulse">🔒 Live</span>
              </div>
              <progress
                className="progress progress-info w-full h-3"
                value={Number(surveyData.currentParticipants)}
                max="10"
              ></progress>
            </div>
          )}

          {/* TODO: create dedicated component handling the display and result */}
          {state === SurveyState.INVALID && (
            <div className="alert alert-error">
              <div className="mt-2">
                <p>Invalid survey</p>
              </div>
            </div>
          )}

          {state === SurveyState.TERMINATED && (
            <div className="bg-primary/5 text-primary px-4 py-2 rounded-md mt-2 text-sm">
              <p>Waiting for the gateway result...</p>
            </div>
          )}

          {state === SurveyState.VALID && (
            <div className="alert-success">
              <div className="mt-2">
                <p>Participants: {surveyData.currentParticipants.toString()}</p>
                <p>Final result: {surveyData.finalResult.toString()}</p>
              </div>
            </div>
          )}

          {/* When completed and valid display analyse button and redirect to another layer */}
          <div className="text-sm opacity-70 mt-2">
            Ends at:{" "}
            {new Date(
              Number(surveyParams.surveyEndTime) * 1000
            ).toLocaleDateString()}
          </div>

          {error && error.message}
        </div>
      </div>
    </div>
  );
};

export default SurveyDisplay;

// TODO: Good idea for engagement after voting. Incentivize participants to share to others
// {
//   /* Post-Vote Engagement */
// }
// {
//   voted && (
//     <section className="container mx-auto px-4 py-12 text-center">
//       <div className="max-w-2xl mx-auto">
//         <h2 className="text-2xl mb-4">
//           Want to see results? Share this poll to unlock faster
//         </h2>
//         <div className="flex gap-4 justify-center mb-8">
//           <button className="btn btn-outline">Twitter</button>
//           <button className="btn btn-outline">Telegram</button>
//           <button className="btn btn-outline">Copy Link</button>
//         </div>

//         <div className="form-control w-96 mx-auto">
//           <input
//             type="email"
//             placeholder="Get notified when results unlock"
//             className="input input-bordered"
//             value={email}
//             onChange={(e) => setEmail(e.target.value)}
//           />
//         </div>

//         {/* Animation Placeholder */}
//         <div className="h-48 bg-base-100/10 rounded-lg mt-8 backdrop-blur-lg">
//           {/* Lottie animation would go here */}
//         </div>
//       </div>
//     </section>
//   );
// }

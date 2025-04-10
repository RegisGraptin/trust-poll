import {
  SurveyData,
  SurveyParams,
  SurveyType,
  useHasVoted,
} from "@/hook/survey";
import { useEffect, useState } from "react";
import { useAccount } from "wagmi";

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
  const { data: hasVoted } = useHasVoted(surveyId, userAddress);

  const [state, setState] = useState<SurveyState>(SurveyState.TERMINATED);

  const onVote = (entry: boolean) => {
    console.log("Here the user entry:", entry);
    // TODO: handle the function called
  };

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

          {surveyParams.metadataNames?.length > 0 && (
            <div>
              <h4 className="font-medium text-gray-600 text-sm mb-1">
                Metadata:
              </h4>
              <ul className="list-disc list-inside text-gray-900 text-sm space-y-1">
                {surveyParams.metadataNames.map((metadataName, index) => (
                  <li key={index}>{metadataName}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
        <div className="flex flex-col gap-2 mt-4">
          {state === SurveyState.ONGOING &&
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

          {state === SurveyState.ONGOING &&
            surveyParams.surveyType === SurveyType.POLLING && (
              <>
                <div>
                  <h2>TODO</h2>
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

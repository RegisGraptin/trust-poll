import {
  SurveyData,
  SurveyParams,
  useSurvey,
  useSurveyDataList,
} from "@/hook/survey";
import { useEffect, useState } from "react";

const SurveyDisplay = ({
  surveyParams,
  surveyData,
}: {
  surveyParams: SurveyParams;
  surveyData: SurveyData;
}) => {
  const [isActive, setIsActive] = useState(false);
  const [hasVoted, setHasVoted] = useState(false);

  const onVote = (entry: boolean) => {
    console.log("Here the user entry:", entry);
  };

  useEffect(() => {
    const checkActive = () => {
      const currentTime = Math.floor(Date.now() / 1000);
      setIsActive(currentTime < surveyParams.surveyEndTime);
    };

    checkActive();
    const interval = setInterval(checkActive, 60000);
    return () => clearInterval(interval);
  }, [surveyParams.surveyEndTime]);

  const getCardStatus = () => {
    // if (!surveyData.isValid) return "border-error";
    if (surveyData.isCompleted) return "border-success";
    return "border-primary";
  };

  const getStatusMessage = () => {
    // if (!surveyData.isValid) return "Survey invalid";
    if (surveyData.isCompleted) return "Survey completed";
    if (!isActive) return "Survey ended";
    return "Ongoing survey";
  };

  return (
    <div
      className={`card w-full bg-base-100 shadow-xl border-2 ${getCardStatus()}`}
    >
      {/* Status Banner */}
      {(!isActive || surveyData.isCompleted || !surveyData.isValid) && (
        <div
          className={`alert ${surveyData.isValid ? "alert-success" : "alert-error"}`}
        >
          <div className="w-full text-center">
            <h3 className="font-bold text-md">{getStatusMessage()}</h3>
          </div>
        </div>
      )}
      <div className="card-body">
        <div className="flex justify-between items-start">
          <h2 className="card-title">{surveyParams.surveyPrompt}</h2>
          {surveyParams.isWhitelisted && (
            <div className="badge badge-info">Whitelisted</div>
          )}
        </div>

        <div className="flex flex-col gap-2 mt-4">
          {isActive && !surveyData.isCompleted && !surveyData.isValid && (
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

          {(!isActive || surveyData.isCompleted || !surveyData.isValid) && (
            <div
              className={`alert ${surveyData.isValid ? "alert-success" : "alert-error"}`}
            >
              <div className="mt-2">
                <p>Participants: {surveyData.currentParticipants.toString()}</p>
                <p>Final result: {surveyData.finalResult.toString()}</p>
              </div>
            </div>
          )}

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

import { useSurvey, useSurveyDataList, writeCreateSurvey } from "@/hook/survey";
import { dateToTimestamps } from "@/utils/date";
import { useState } from "react";
import { useWaitForTransactionReceipt, useWriteContract } from "wagmi";

const SurveyCreationForm = () => {
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [question, setQuestion] = useState("");
  const [options, setOptions] = useState(["", ""]);
  const [threshold, setThreshold] = useState(10);
  const [endSurveyTime, setEndSurveyTime] = useState("");

  const [surveyType, setSurveyType] = useState("polling");

  const {
    data: hash,
    error,
    writeContract,
    isPending: txIsPending,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({
      hash,
    });

  const createNewSurvey = () => {
    console.log("Process...");

    const surveyParams = {
      surveyPrompt: question,
      surveyType: surveyType == "polling" ? 0 : 1,
      isWhitelisted: false,
      whitelistRootHash:
        "0x0000000000000000000000000000000000000000000000000000000000000000", // FIXME: Can we improve this
      surveyEndTime: dateToTimestamps(endSurveyTime),
      minResponseThreshold: threshold,
      metadataTypes: ([] = []),
      constraints: ([] = []),
    };

    console.log(surveyParams);

    writeCreateSurvey(writeContract, surveyParams);
  };

  return (
    <section className="container mx-auto px-4 py-12">
      <h2 className="text-3xl font-bold text-center mb-8">
        Start a Private Poll/Benchmark in 20 Seconds
      </h2>
      <div className="flex flex-col lg:flex-row gap-8 max-w-6xl mx-auto">
        <div className="flex-1 card bg-base-100/10 backdrop-blur-lg">
          {/* Survey type */}
          <div className="card-body">
            <div className="flex flex justify-center space-x-4">
              <input
                type="radio"
                name="mode"
                id="polling"
                value="polling"
                checked={surveyType === "polling"}
                onChange={() => setSurveyType("polling")}
                className="hidden peer/polling"
              />
              <label
                htmlFor="polling"
                className="btn btn-outline peer-checked/polling:btn-primary transition-all duration-200"
              >
                Polling
              </label>

              <input
                type="radio"
                name="mode"
                id="benchmark"
                value="benchmark"
                checked={surveyType === "benchmark"}
                onChange={() => setSurveyType("benchmark")}
                className="hidden peer/benchmark"
              />
              <label
                htmlFor="benchmark"
                className="btn btn-outline peer-checked/benchmark:btn-primary transition-all duration-200"
              >
                Benchmark
              </label>
            </div>
          </div>

          <div className="card-body">
            <input
              type="text"
              placeholder="Your question..."
              className="input input-bordered mb-4"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
            />

            {/* Yes / No */}
            {["Yes", "No"].map((opt, i) => (
              <input
                key={i}
                type="text"
                placeholder={`Option ${i + 1}`}
                className="input input-bordered mb-2"
                value={opt}
                disabled={true}
              />
            ))}

            <input
              type="date"
              placeholder="Survey End Time"
              className="input input-bordered mb-4"
              value={endSurveyTime}
              onChange={(e) => setEndSurveyTime(e.target.value)}
            />

            <div className="mt-4">
              <label className="label">Threshold: {threshold}</label>
              <input
                type="range"
                min="5"
                max="100"
                className="range range-xs range-info"
                value={threshold}
                onChange={(e) => setThreshold(parseInt(e.target.value))}
              />
            </div>

            <div className="collapse">
              <input
                type="checkbox"
                checked={showAdvanced}
                onChange={() => setShowAdvanced(!showAdvanced)}
              />
              <div className="collapse-title">Advanced Settings</div>
              <div className="collapse-content">
                {/* Advanced settings fields */}
              </div>
            </div>

            <div>
              <button className="btn" onClick={() => createNewSurvey()}>
                Create a new Survey
              </button>
            </div>
            <div>{error?.message}</div>
          </div>
        </div>

        {/* Live Preview */}
        <div className="flex-1 card bg-base-100/10 backdrop-blur-lg">
          <div className="card-body">
            <h3 className="font-bold mb-4">Preview</h3>
            <p className="text-lg mb-4">{question || "Your question here"}</p>
            <div className="space-y-2">
              {["Yes", "No"].map((opt, i) => (
                <button key={i} className="btn btn-block btn-outline">
                  {opt || `Option ${i + 1}`}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default SurveyCreationForm;

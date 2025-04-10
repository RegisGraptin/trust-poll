import {
  MetadataType,
  useSurvey,
  useSurveyDataList,
  writeCreateSurvey,
} from "@/hook/survey";
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

  const [metadataFields, setMetadataFields] = useState<
    { name: string; type: MetadataType }[]
  >([]);

  const addMetadataField = () => {
    if (metadataFields.length < 5) {
      setMetadataFields([
        ...metadataFields,
        { name: "", type: MetadataType.BOOLEAN },
      ]);
    }
  };

  const updateMetadataField = (
    index: number,
    key: "name" | "type",
    value: string
  ) => {
    const updated = [...metadataFields];
    if (key == "type")
      updated[index][key] = MetadataType[value as keyof typeof MetadataType];
    else updated[index][key] = value;
    setMetadataFields(updated);
  };

  const removeMetadataField = (index: number) => {
    const updated = metadataFields.filter((_, i) => i !== index);
    setMetadataFields(updated);
  };

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

    // Extract metadata
    let metadataNames: string[] = [];
    let metadataTypes: MetadataType[] = [];

    metadataFields.map((metadata) => {
      metadataNames.push(metadata.name);
      metadataTypes.push(metadata.type);
    });

    const surveyParams = {
      surveyPrompt: question,
      surveyType: surveyType == "polling" ? 0 : 1,
      isWhitelisted: false,
      whitelistRootHash: "0x" + "0".repeat(64), // Empty hash root
      surveyEndTime: dateToTimestamps(endSurveyTime),
      minResponseThreshold: threshold,
      metadataNames: metadataNames,
      metadataTypes: metadataTypes,
      constraints: [],
    };

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

            {surveyType === "polling" ? (
              ["Yes", "No"].map((opt, i) => (
                <input
                  key={i}
                  type="text"
                  placeholder={`Option ${i + 1}`}
                  className="input input-bordered mb-2"
                  value={opt}
                  disabled
                />
              ))
            ) : (
              <input
                type="text"
                placeholder="User entry"
                className="input input-bordered mb-2"
                disabled
              />
            )}

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

            <div className="mt-4">
              {/* Metadata Dynamic Form */}
              <div className="space-y-4">
                {metadataFields.map((field, index) => (
                  <div key={index} className="flex items-center gap-2">
                    <input
                      type="text"
                      placeholder="Metadata name"
                      className="input input-bordered w-full"
                      value={field.name}
                      onChange={(e) =>
                        updateMetadataField(index, "name", e.target.value)
                      }
                    />
                    <select
                      className="select select-bordered"
                      value={MetadataType[field.type]}
                      onChange={(e) =>
                        updateMetadataField(index, "type", e.target.value)
                      }
                    >
                      <option value="BOOLEAN">boolean</option>
                      <option value="UINT256">uint256</option>
                    </select>
                    <button
                      className="btn btn-circle btn-outline text-error"
                      onClick={() => removeMetadataField(index)}
                      type="button"
                    >
                      ✕
                    </button>
                  </div>
                ))}

                {metadataFields.length < 5 && (
                  <button
                    type="button"
                    className="btn btn-sm btn-outline btn-primary"
                    onClick={addMetadataField}
                  >
                    + Add metadata
                  </button>
                )}
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

        <div className="flex-1 card bg-base-100/10 backdrop-blur-lg h-full min-h-[300px]">
          <div className="card-body flex flex-col justify-between">
            {/* Content */}
            <div>
              <h3 className="font-bold mb-4">Preview</h3>
              <p className="text-lg mb-4">{question || "Your question here"}</p>

              {/* Metadata Preview */}
              {metadataFields.length > 0 && (
                <div className="mt-4">
                  <h4 className="font-semibold text-sm text-secondary mb-2">
                    Encrypted Metadata Fields
                  </h4>
                  <ul className="space-y-2">
                    {metadataFields.map((meta, index) => (
                      <li
                        key={index}
                        className="flex items-center justify-between text-sm bg-base-200 px-3 py-2 rounded-md"
                      >
                        <span className="font-medium">
                          {meta.name || `Field ${index + 1}`}
                        </span>
                        <span className="badge badge-outline">
                          {MetadataType[meta.type].toLowerCase()}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* Polling Settings */}
            <div className="mt-6">
              <h4 className="font-semibold text-sm text-primary mb-2">
                Survey Settings
              </h4>
              <div className="space-y-2 text-sm text-base-content">
                <div className="flex items-center justify-between bg-base-100 border border-base-300 px-3 py-2 rounded-md">
                  <span className="font-medium">Min Threshold</span>
                  <span>{threshold}</span>
                </div>

                {endSurveyTime && (
                  <div className="flex items-center justify-between bg-base-100 border border-base-300 px-3 py-2 rounded-md">
                    <span className="font-medium">Ends At</span>
                    <span>{new Date(endSurveyTime).toLocaleDateString()}</span>
                  </div>
                )}
              </div>
            </div>

            {/* Options */}
            <div className="space-y-2 mt-6">
              {surveyType === "polling" ? (
                ["Yes", "No"].map((opt, i) => (
                  <button key={i} className="btn btn-block btn-outline">
                    {opt || `Option ${i + 1}`}
                  </button>
                ))
              ) : (
                <input
                  type="text"
                  placeholder="User entry"
                  className="input input-bordered mb-2"
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default SurveyCreationForm;

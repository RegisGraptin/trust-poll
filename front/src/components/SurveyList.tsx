import { useSurveyDataList } from "@/hook/survey";
import SurveyDisplay from "./SurveyDisplay";
import React from "react";
import { createFHEInstance } from "@/lib/fhe";

const SurveyList = () => {
  // Load the FHE module
  React.useEffect(() => {
    createFHEInstance();
  }, []);

  const { data: surveyDataResult } = useSurveyDataList();

  return (
    <>
      <div className="container mx-auto p-4">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4 gap-6">
          {surveyDataResult &&
            surveyDataResult.map((data, index: number) => {
              const surveyDetails = data.result;

              return (
                <SurveyDisplay
                  key={index}
                  surveyId={index}
                  surveyParams={surveyDetails[0]}
                  surveyData={surveyDetails[1]}
                />
              );
            })}
        </div>
      </div>
    </>
  );
};

export default SurveyList;

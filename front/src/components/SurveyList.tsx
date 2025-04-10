import { SurveyData, useSurvey, useSurveyDataList } from "@/hook/survey";
import SurveyDisplay from "./SurveyDisplay";

const SurveyList = () => {
  const { data: surveyDataResult } = useSurveyDataList();
  console.log(surveyDataResult);

  return (
    <>
      {/* FIXME: see called action here or in the other layer */}

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

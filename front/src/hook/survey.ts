import { Abi, Address, getAddress } from "viem";
import { useReadContract, useReadContracts } from "wagmi";
import Survey from "@/abi/Survey.json";

const SURVEY_CONTRACT_ADDRESS =
  process.env.NEXT_PUBLIC_SURVEY_CONTRACT_ADDRESS!;

export type SurveyParams = {
  surveyPrompt: string;
  surveyType: Number;
  isWhitelisted: boolean;
  whitelistRootHash: string;
  surveyEndTime: number;
  minResponseThreshold: Number;
  metadataTypes: [];
  constraints: [][];
};

export interface SurveyData {
  currentParticipants: bigint;
  encryptedResponses: bigint;
  finalResult: bigint;
  isCompleted: boolean;
  isValid: boolean;
}

export function useSurvey<TFunctionName extends string>(
  functionName: TFunctionName,
  args?: any[]
) {
  return useReadContract({
    address: getAddress(SURVEY_CONTRACT_ADDRESS!),
    abi: Survey.abi,
    functionName,
    args,
    query: {
      enabled: !!SURVEY_CONTRACT_ADDRESS, // Only enable when address exists
    },
  });
}

export function _useSurveyDetailsList(lastSurveyId: number | undefined) {
  return useReadContracts({
    query: { enabled: !!lastSurveyId },
    contracts: Array.from({ length: Number(lastSurveyId) }).map((_, index) => ({
      abi: Survey.abi as Abi,
      address: getAddress(SURVEY_CONTRACT_ADDRESS),
      functionName: "surveyDetails",
      args: [index],
    })),
  }) as {
    data?: { status: "success"; result: [SurveyParams, SurveyData] }[];
  };
}

export function useSurveyDataList() {
  const { data: lastSurveyIdResponse } = useSurvey("lastSurveyId");

  const lastSurveyId =
    lastSurveyIdResponse !== undefined
      ? Number(lastSurveyIdResponse)
      : undefined;

  return _useSurveyDetailsList(lastSurveyId ?? 0);
}

export function writeCreateSurvey(
  writeContract: any,
  surveyParams: SurveyParams
) {
  return writeContract({
    address: SURVEY_CONTRACT_ADDRESS,
    abi: Survey.abi,
    functionName: "createSurvey",
    args: [surveyParams],
  });
}

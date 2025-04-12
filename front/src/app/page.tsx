import Landing from "@/components/Landing";
import type { Metadata, NextPage } from "next";
import React from "react";

export const metadata: Metadata = {
  title: "Trust Poll - Encrypted polling and benchmarking",
  description:
    "Create encrypted polling and benchmarking and get reward form it",
  keywords: "encrypted, polling, benchmarking, FHE",
};

const Home: NextPage = () => {
  return <Landing />;
};

export default Home;

import Landing from "@/components/Landing";
import type { Metadata, NextPage } from "next";
import React from "react";

export const metadata: Metadata = {
  title: "FIXME:",
  description:"FIXME:",
  keywords:"FIXME:",
  alternates: {
    canonical: "FIXME:",
  },
};

const Home: NextPage = () => {
  return (
    // <main className="bg-gray-50 min-h-screen">
     
     <Landing />
    // </main>
  );
};

export default Home;

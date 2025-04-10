"use client";

import SurveyList from "./SurveyList";
import SurveyCreationForm from "./SurveyCreationForm";
import Header from "./Header";

export default function Landing() {
  return (
    <>
      <Header />
      <div className="min-h-screen bg-[#0A1A2F] text-white font-inter">
        <section className="container mx-auto px-4 py-20 text-center">
          <h1 className="font-space-grotesk text-4xl font-bold mb-4">
            Vote Anonymously & Get rewarded from it!
          </h1>
          <p className="text-gray-300 mb-8">
            {/* FIXME: more punchy catch line here */}
            Participate to survey while encrypted your data. Survey entry and
            metadata are preserved by leveraging FHE.
          </p>

          <SurveyList />
        </section>

        {/* Create Poll CTA */}
        <SurveyCreationForm />

        {/* Footer */}
        <footer className="border-t border-base-100/20 mt-20 py-8">
          <div className="container mx-auto px-4 flex justify-between">
            <div className="flex items-center gap-2">
              <span>🔐 12,345 votes secured this week</span>
            </div>
            <div className="flex gap-4">
              <span>Source code:</span>
              <a
                href="https://github.com/RegisGraptin/trust-poll"
                title="Github Project Code"
              >
                Github
              </a>
            </div>
          </div>
        </footer>
      </div>
    </>
  );
}

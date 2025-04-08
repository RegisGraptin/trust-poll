"use client";

import { useState } from "react";
import SurveyList from "./SurveyList";
import SurveyCreationForm from "./SurveyCreationForm";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function Landing() {
  const [votes, setVotes] = useState(3);
  const [voted, setVoted] = useState(false);
  const [email, setEmail] = useState("");

  return (
    <div className="min-h-screen bg-[#0A1A2F] text-white font-inter">
      {/* Hero Section */}

      <ConnectButton />

      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="font-space-grotesk text-4xl font-bold mb-4">
          Vote Anonymously. Results Unlocked Collectively.
        </h1>
        <p className="text-gray-300 mb-8">
          Your vote is encrypted. Results update only after 10+ participants to
          ensure anonymity.
        </p>

        <section>
          <SurveyList />
        </section>

        {/* Mock Poll */}
        <div className="card bg-base-100/10 max-w-md mx-auto backdrop-blur-lg">
          <div className="card-body">
            <h2 className="card-title">
              Should blockchain voting replace traditional polls? 🔒
            </h2>
            <div className="flex gap-4 justify-center my-4">
              <button
                className="btn btn-success gap-2"
                onClick={() => setVoted(true)}
              >
                Yes
              </button>
              <button
                className="btn btn-error gap-2"
                onClick={() => setVoted(true)}
              >
                No
              </button>
            </div>

            {/* Progress Bar */}
            <div className="mt-6">
              <div className="flex justify-between mb-2">
                <span>{votes}/10 votes collected</span>
                <span className="animate-pulse">🔒 Live</span>
              </div>
              <progress
                className="progress progress-info w-full h-3"
                value={votes}
                max="10"
              ></progress>
            </div>
          </div>
        </div>

        {/* Trust Badges */}
        <div className="flex justify-center gap-8 mt-8">
          <div className="tooltip" data-tip="Zero-Knowledge Encryption">
            🔒
          </div>
          <div className="tooltip" data-tip="Delayed Results">
            ⏳
          </div>
        </div>
      </section>

      {/* Post-Vote Engagement */}
      {voted && (
        <section className="container mx-auto px-4 py-12 text-center">
          <div className="max-w-2xl mx-auto">
            <h2 className="text-2xl mb-4">
              Want to see results? Share this poll to unlock faster
            </h2>
            <div className="flex gap-4 justify-center mb-8">
              <button className="btn btn-outline">Twitter</button>
              <button className="btn btn-outline">Telegram</button>
              <button className="btn btn-outline">Copy Link</button>
            </div>

            <div className="form-control w-96 mx-auto">
              <input
                type="email"
                placeholder="Get notified when results unlock"
                className="input input-bordered"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>

            {/* Animation Placeholder */}
            <div className="h-48 bg-base-100/10 rounded-lg mt-8 backdrop-blur-lg">
              {/* Lottie animation would go here */}
            </div>
          </div>
        </section>
      )}

      {/* Create Poll CTA */}
      <SurveyCreationForm />

      {/* Footer */}
      <footer className="border-t border-base-100/20 mt-20 py-8">
        <div className="container mx-auto px-4 flex justify-between">
          <div className="flex items-center gap-2">
            <span>🔐 12,345 votes secured this week</span>
          </div>
          <div className="flex gap-4">
            <span>Built by:</span>
            <span>Github</span>
            <span>Zama FHE</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

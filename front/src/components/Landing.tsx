"use client";

import { useState } from 'react';

export default function Landing() {
  const [votes, setVotes] = useState(3);
  const [voted, setVoted] = useState(false);
  const [email, setEmail] = useState('');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);
  const [threshold, setThreshold] = useState(10);

  return (
    <div className="min-h-screen bg-[#0A1A2F] text-white font-inter">
      {/* Hero Section */}
      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="font-space-grotesk text-4xl font-bold mb-4">
          Vote Anonymously. Results Unlocked Collectively.
        </h1>
        <p className="text-gray-300 mb-8">
          Your vote is encrypted. Results update only after 10+ participants to ensure anonymity.
        </p>

        {/* Mock Poll */}
        <div className="card bg-base-100/10 max-w-md mx-auto backdrop-blur-lg">
          <div className="card-body">
            <h2 className="card-title">Should blockchain voting replace traditional polls? 🔒</h2>
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
            <h2 className="text-2xl mb-4">Want to see results? Share this poll to unlock faster</h2>
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
      <section className="container mx-auto px-4 py-12">
        <h2 className="text-3xl font-bold text-center mb-8">Start a Private Poll in 20 Seconds</h2>
        <div className="flex flex-col lg:flex-row gap-8 max-w-6xl mx-auto">
          <div className="flex-1 card bg-base-100/10 backdrop-blur-lg">
            <div className="card-body">
              <input
                type="text"
                placeholder="Your question..."
                className="input input-bordered mb-4"
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
              />
              
              {options.map((opt, i) => (
                <input
                  key={i}
                  type="text"
                  placeholder={`Option ${i + 1}`}
                  className="input input-bordered mb-2"
                  value={opt}
                  onChange={(e) => {
                    const newOptions = [...options];
                    newOptions[i] = e.target.value;
                    setOptions(newOptions);
                  }}
                />
              ))}
              
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
                <input type="checkbox" checked={showAdvanced} onChange={() => setShowAdvanced(!showAdvanced)} />
                <div className="collapse-title">Advanced Settings</div>
                <div className="collapse-content">
                  {/* Advanced settings fields */}
                </div>
              </div>
            </div>
          </div>

          {/* Live Preview */}
          <div className="flex-1 card bg-base-100/10 backdrop-blur-lg">
            <div className="card-body">
              <h3 className="font-bold mb-4">Preview</h3>
              <p className="text-lg mb-4">{question || "Your question here"}</p>
              <div className="space-y-2">
                {options.map((opt, i) => (
                  <button key={i} className="btn btn-block btn-outline">
                    {opt || `Option ${i + 1}`}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-base-100/20 mt-20 py-8">
        <div className="container mx-auto px-4 flex justify-between">
          <div className="flex items-center gap-2">
            <span>🔐 12,345 votes secured this week</span>
          </div>
          <div className="flex gap-4">
            <span>Audited by:</span>
            <span>CertiK</span>
            <span>Quantstamp</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
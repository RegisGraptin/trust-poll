import "../styles/globals.css";
import "@rainbow-me/rainbowkit/styles.css";
import { GoogleAnalytics } from "@next/third-parties/google";

import { WalletProvider } from "../components/wallet/WalletProvider";
import { Metadata } from "next";

export const metadata: Metadata = {
  icons: [
    {
      rel: "icon",
      url: "/images/favicon/favicon.ico",
    },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head></head>
      <body>
        <WalletProvider>{children}</WalletProvider>
      </body>
      {!process.env.DEV_ENV && <GoogleAnalytics gaId="G-Q0HR0JQKQS" />}
    </html>
  );
}

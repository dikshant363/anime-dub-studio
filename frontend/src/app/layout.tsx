import "./globals.css";
import React from "react";

export const metadata = {
  title: "Anime Dub Studio — Local-First AI Dubbing",
  description: "Japanese Anime to Natural Hindi Dubbing Studio powered by Apple Silicon M4 & MLX",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-[#0a0a0c] text-[#f4f4f6] selection:bg-neutral-800">
        {children}
      </body>
    </html>
  );
}

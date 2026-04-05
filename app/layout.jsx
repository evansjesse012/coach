export const metadata = { title: 'Coach', description: 'AI-powered personal training companion' };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

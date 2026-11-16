import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath, URL } from "node:url";

// Ang lahat ng "/api" requests ay ipinapasa sa Python API; puwedeng i-override ang target gamit ang API_PROXY_TARGET.
// "@" = ang src folder (ginagamit ng shadcn/ui: import { Button } from "@/components/ui/button")
export default defineConfig({
  base: process.env.VITE_BASE_PATH || "/",
  plugins: [react()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  server: {
    port: 5173,
    proxy: { "/api": process.env.API_PROXY_TARGET || "http://localhost:8001" },
    watch: {
      ignored: ["**/dist/**", "**/public/elegant-notification-sound.ogg"],
    },
  },
});

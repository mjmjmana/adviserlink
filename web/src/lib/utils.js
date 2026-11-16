import { clsx } from "clsx";
import { twMerge } from "tailwind-merge";

// Pinagsasama ang Tailwind classes nang walang banggaan (ginagamit ng lahat ng shadcn components)
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

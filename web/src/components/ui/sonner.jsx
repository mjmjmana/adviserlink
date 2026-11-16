import { Toaster as Sonner } from "sonner";

// Pop-up na notification na kusang nawawala (fade). Iisa lang ang toast: pinapalitan lang ang laman kapag may bago.
export function Toaster(props) {
  return (
    <Sonner
      position="top-right"
      toastOptions={{
        classNames: {
          toast: "!rounded-2xl !border-0 !bg-primary !text-primary-foreground !font-semibold !shadow-xl",
          actionButton: "!bg-background !text-foreground !rounded-full",
        },
      }}
      {...props}
    />
  );
}

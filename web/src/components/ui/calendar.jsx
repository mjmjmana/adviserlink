import * as React from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { DayPicker } from "react-day-picker";
import { cn } from "@/lib/utils";
import { buttonVariants } from "@/components/ui/button";

// shadcn/ui Calendar (react-day-picker). Pinalapad ko ang mga cell para punô ang card at pantay-pantay ang laki.
function Calendar({ className, classNames, showOutsideDays = true, ...props }) {
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn("w-full", className)}
      classNames={{
        months: "flex w-full flex-col",
        month: "w-full space-y-3",
        caption: "relative flex items-center justify-center pt-1",
        caption_label: "text-base font-bold",
        nav: "flex items-center",
        nav_button: cn(buttonVariants({ variant: "outline", size: "icon" }), "h-8 w-8 border-card-foreground/30 bg-transparent p-0 opacity-80 hover:opacity-100"),
        nav_button_previous: "absolute left-1",
        nav_button_next: "absolute right-1",
        table: "w-full border-collapse",
        head_row: "flex w-full gap-1",
        head_cell: "flex-1 text-center text-xs font-bold text-muted-foreground",
        row: "mt-1 flex w-full gap-1",
        cell: "relative aspect-square flex-1 p-0 text-center text-sm focus-within:relative focus-within:z-20",
        day: cn(buttonVariants({ variant: "ghost" }), "relative h-full w-full rounded-xl bg-secondary p-0 font-semibold aria-selected:opacity-100 aria-selected:after:bg-primary-foreground"),
        day_selected: "!bg-primary !text-primary-foreground hover:!bg-primary",
        day_today: "ring-2 ring-card-foreground",
        day_outside: "opacity-40",
        day_disabled: "opacity-30",
        day_hidden: "invisible",
        ...classNames,
      }}
      components={{
        IconLeft: () => <ChevronLeft className="h-4 w-4" />,
        IconRight: () => <ChevronRight className="h-4 w-4" />,
      }}
      {...props}
    />
  );
}
Calendar.displayName = "Calendar";

export { Calendar };

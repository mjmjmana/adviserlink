import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * @typedef {Object} InputProps
 * @property {React.InputHTMLAttributes<HTMLInputElement>} [props]
 * @property {string} [label]
 * @property {string} [hint]
 * @property {string} [error]
 * @property {React.ReactNode} [iconLeft]
 * @property {React.ReactNode} [iconRight]
 * @property {boolean} [fullWidth]
 */

const Input = React.forwardRef(
  /** @param {InputProps & {className?: string, type?: string, disabled?: boolean, required?: boolean, id?: string}} props */
  /** @param {React.Ref<HTMLInputElement>} ref */
  ({ className, type = "text", label, hint, error, iconLeft, iconRight, fullWidth = true, disabled, required, id, ...props }, ref) => {
    const inputId = id || label?.toLowerCase().replace(/\s+/g, "-");
    const errorId = error ? `${inputId}-error` : undefined;
    const hintId = hint ? `${inputId}-hint` : undefined;

    return (
      <div className={cn("w-full", fullWidth && "max-w-full")}>
        {label && (
          <label htmlFor={inputId} className="mb-1.5 block text-sm font-medium text-foreground">
            {label}
            {required && <span className="text-destructive ml-1" aria-hidden="true">*</span>}
          </label>
        )}
        <div className="relative">
          {iconLeft && (
            <div className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground/70">
              {iconLeft}
            </div>
          )}
          <input
            type={type}
            id={inputId}
            ref={ref}
            disabled={disabled}
            required={required}
            aria-invalid={error ? "true" : "false"}
            aria-describedby={cn(errorId, hintId)}
            className={cn(
              "flex h-11 w-full rounded-2xl border bg-input px-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground/60",
              "transition-all duration-200 ease-out",
              "border-border",
              "focus:outline-none focus:ring-2 focus:ring-ring/30 focus:ring-offset-2 focus:ring-offset-background focus:border-transparent focus:shadow-[0_0_0_1px_hsl(var(--ring))]",
              "disabled:cursor-not-allowed disabled:opacity-50",
              "hover:border-border/60",
              iconLeft && "pl-11",
              iconRight && "pr-11",
              error && "border-destructive focus:ring-destructive/30 focus:shadow-[0_0_0_1px_hsl(var(--destructive))]",
              className
            )}
            {...props}
          />
          {iconRight && (
            <div className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground/70">
              {iconRight}
            </div>
          )}
        </div>
        {error && (
          <p id={errorId} className="mt-2 text-sm text-destructive flex items-center gap-1" role="alert">
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            {error}
          </p>
        )}
        {hint && !error && (
          <p id={hintId} className="mt-2 text-sm text-muted-foreground">
            {hint}
          </p>
        )}
      </div>
    );
  }
);
Input.displayName = "Input";

/**
 * @typedef {Object} TextareaProps
 * @property {React.TextareaHTMLAttributes<HTMLTextAreaElement>} [props]
 * @property {string} [label]
 * @property {string} [hint]
 * @property {string} [error]
 * @property {boolean} [fullWidth]
 */

const Textarea = React.forwardRef(
  /** @param {TextareaProps & {className?: string, disabled?: boolean, required?: boolean, id?: string}} props */
  /** @param {React.Ref<HTMLTextAreaElement>} ref */
  ({ className, label, hint, error, fullWidth = true, disabled, required, id, ...props }, ref) => {
    const textareaId = id || label?.toLowerCase().replace(/\s+/g, "-");
    const errorId = error ? `${textareaId}-error` : undefined;
    const hintId = hint ? `${textareaId}-hint` : undefined;

    return (
      <div className={cn("w-full", fullWidth && "max-w-full")}>
        {label && (
          <label htmlFor={textareaId} className="mb-2 block text-sm font-medium text-foreground">
            {label}
            {required && <span className="text-destructive ml-1" aria-hidden="true">*</span>}
          </label>
        )}
        <textarea
          id={textareaId}
          ref={ref}
          disabled={disabled}
          required={required}
          aria-invalid={error ? "true" : "false"}
          aria-describedby={cn(errorId, hintId)}
          className={cn(
            "flex min-h-[100px] w-full rounded-2xl border bg-input px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground",
            "transition-all duration-200",
            "border-border",
            "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:ring-offset-background focus:border-transparent",
            "disabled:cursor-not-allowed disabled:opacity-50",
            "resize-y",
            "hover:border-border/80",
            error && "border-destructive focus:ring-destructive",
            className
          )}
          {...props}
        />
        {error && (
          <p id={errorId} className="mt-2 text-sm text-destructive flex items-center gap-1" role="alert">
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            {error}
          </p>
        )}
        {hint && !error && (
          <p id={hintId} className="mt-2 text-sm text-muted-foreground">
            {hint}
          </p>
        )}
      </div>
    );
  }
);
Textarea.displayName = "Textarea";

/**
 * @typedef {Object} SelectProps
 * @property {React.SelectHTMLAttributes<HTMLSelectElement>} [props]
 * @property {string} [label]
 * @property {string} [hint]
 * @property {string} [error]
 * @property {string} [placeholder]
 * @property {Array<{value: string, label: string, disabled?: boolean}>} options
 * @property {boolean} [fullWidth]
 */

const Select = React.forwardRef(
  /** @param {SelectProps & {className?: string, disabled?: boolean, required?: boolean, id?: string}} props */
  /** @param {React.Ref<HTMLSelectElement>} ref */
  ({ className, label, hint, error, placeholder, options, fullWidth = true, disabled, required, id, ...props }, ref) => {
    const selectId = id || label?.toLowerCase().replace(/\s+/g, "-");
    const errorId = error ? `${selectId}-error` : undefined;
    const hintId = hint ? `${selectId}-hint` : undefined;

    return (
      <div className={cn("w-full", fullWidth && "max-w-full")}>
        {label && (
          <label htmlFor={selectId} className="mb-2 block text-sm font-medium text-foreground">
            {label}
            {required && <span className="text-destructive ml-1" aria-hidden="true">*</span>}
          </label>
        )}
        <div className="relative">
          <select
            id={selectId}
            ref={ref}
            disabled={disabled}
            required={required}
            aria-invalid={error ? "true" : "false"}
            aria-describedby={cn(errorId, hintId)}
            className={cn(
              "flex h-11 w-full rounded-2xl border bg-input px-4 py-2.5 text-sm text-foreground",
              "transition-all duration-200",
              "border-border",
              "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:ring-offset-background focus:border-transparent",
              "disabled:cursor-not-allowed disabled:opacity-50",
              "appearance-none bg-no-repeat bg-right",
              "bg-[url('data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2216%22%20height%3D%2216%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%23A1A1AA%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Cpath%20d%3D%22m6%209%206%206%206-6%22%2F%3E%3C%2Fsvg%3E')] bg-center pr-10",
              "hover:border-border/80",
              error && "border-destructive focus:ring-destructive",
              className
            )}
            {...props}
          >
            {placeholder && <option value="" disabled selected>{placeholder}</option>}
            {options.map((opt) => (
              <option key={opt.value} value={opt.value} disabled={opt.disabled}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
        {error && (
          <p id={errorId} className="mt-2 text-sm text-destructive flex items-center gap-1" role="alert">
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            {error}
          </p>
        )}
        {hint && !error && (
          <p id={hintId} className="mt-2 text-sm text-muted-foreground">
            {hint}
          </p>
        )}
      </div>
    );
  }
);
Select.displayName = "Select";

/**
 * @typedef {Object} LabelProps
 * @property {React.LabelHTMLAttributes<HTMLLabelElement>} [props]
 * @property {boolean} [required]
 */

const Label = React.forwardRef(
  /** @param {LabelProps & {className?: string, children?: React.ReactNode}} props */
  /** @param {React.Ref<HTMLLabelElement>} ref */
  ({ className, required, children, ...props }, ref) => (
    <label ref={ref} className={cn("text-sm font-medium text-foreground", className)} {...props}>
      {children}
      {required && <span className="text-destructive ml-1" aria-hidden="true">*</span>}
    </label>
  )
);
Label.displayName = "Label";

export { Input, Textarea, Select, Label };
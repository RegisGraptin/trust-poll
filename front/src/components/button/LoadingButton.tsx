import { ReactNode } from "react";

export default function LoadingButton({
  children,
  isLoading,
  onClick,
  className,
  disabled,
  ...props
}: {
  children: ReactNode;
  isLoading: boolean;
  onClick: () => void;
  className?: string;
  disabled?: boolean;
}) {
  return (
    <button
      {...props}
      className={`${className} ${
        disabled || isLoading
          ? "!bg-gray-400 cursor-not-allowed"
          : "bg-blue-600 hover:bg-blue-700"
      }`}
      type="button"
      onClick={onClick}
      disabled={disabled || isLoading}
    >
      {isLoading ? (
        <div className="flex items-center justify-center gap-2">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent" />
          <span>Loading...</span>
        </div>
      ) : (
        children
      )}
    </button>
  );
}

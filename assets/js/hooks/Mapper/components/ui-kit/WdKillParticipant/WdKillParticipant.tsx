import clsx from 'clsx';
import type { ReactNode } from 'react';

export interface WdKillParticipantProps {
  className?: string;
  role: string;
  value: string;
  valueClassName?: string;
  primaryImageUrl?: string | null;
  primaryImageAlt: string;
  primaryImageHref?: string;
  secondaryImageUrl?: string | null;
  secondaryImageAlt: string;
  secondaryImageHref?: string;
  secondaryImageFit?: 'contain' | 'cover';
  title: string;
  titleHref?: string;
  subtitle: string;
  subtitleHref?: string;
  subtitleImageUrl?: string | null;
  subtitleImageAlt: string;
  detail: string;
  detailHref?: string;
}

interface WdKillParticipantLinkProps {
  href?: string;
  className: string;
  linkedClassName?: string;
  children: ReactNode;
}

const SECONDARY_IMAGE_FIT_CLASSES = {
  contain: 'object-contain',
  cover: 'object-cover',
} as const;

const WdKillParticipantLink = ({ href, className, linkedClassName, children }: WdKillParticipantLinkProps) => {
  if (!href) {
    return <span className={clsx(className, href && linkedClassName)}>{children}</span>;
  }

  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={clsx(className, href && linkedClassName)}>
      {children}
    </a>
  );
};

export const WdKillParticipant = ({
  className,
  role,
  value,
  valueClassName,
  primaryImageUrl,
  primaryImageAlt,
  primaryImageHref,
  secondaryImageUrl,
  secondaryImageAlt,
  secondaryImageHref,
  secondaryImageFit = 'contain',
  title,
  titleHref,
  subtitle,
  subtitleHref,
  subtitleImageUrl,
  subtitleImageAlt,
  detail,
  detailHref,
}: WdKillParticipantProps) => {
  return (
    <div className={clsx('min-w-0', className)}>
      <div className="mb-1.5 flex items-center justify-between gap-2">
        <span className="text-[0.65rem] uppercase tracking-wider text-stone-500">{role}</span>
        <span className={clsx('truncate text-[0.65rem]', valueClassName)}>{value}</span>
      </div>

      <div className="flex min-w-0 gap-2">
        <div className="relative h-14 w-14 shrink-0 border border-stone-700 bg-stone-950/70">
          {primaryImageUrl && (
            <WdKillParticipantLink
              href={primaryImageHref}
              className="block h-full w-full"
              linkedClassName="transition-opacity hover:opacity-80"
            >
              <img src={primaryImageUrl} alt={primaryImageAlt} className="h-full w-full object-contain" />
            </WdKillParticipantLink>
          )}
          {secondaryImageUrl && (
            <WdKillParticipantLink
              href={secondaryImageHref}
              className="absolute -bottom-1 -right-1 block h-6 w-6 border border-stone-600 bg-stone-900"
              linkedClassName="transition-opacity hover:opacity-80"
            >
              <img
                src={secondaryImageUrl}
                alt={secondaryImageAlt}
                className={clsx('h-full w-full', SECONDARY_IMAGE_FIT_CLASSES[secondaryImageFit])}
              />
            </WdKillParticipantLink>
          )}
        </div>

        <div className="min-w-0 flex-1">
          <WdKillParticipantLink
            href={titleHref}
            className="block truncate text-xs font-medium text-stone-100"
            linkedClassName="hover:text-sky-300"
          >
            {title}
          </WdKillParticipantLink>
          <WdKillParticipantLink
            href={subtitleHref}
            className="mt-0.5 flex min-w-0 items-center gap-1 text-[0.7rem] text-stone-400"
            linkedClassName="hover:text-sky-300"
          >
            {subtitleImageUrl && (
              <img src={subtitleImageUrl} alt={subtitleImageAlt} className="h-4 w-4 object-contain" />
            )}
            <span className="truncate">{subtitle}</span>
          </WdKillParticipantLink>
          <WdKillParticipantLink
            href={detailHref}
            className="mt-1 block truncate text-[0.7rem] text-stone-300"
            linkedClassName="hover:text-sky-300"
          >
            {detail}
          </WdKillParticipantLink>
        </div>
      </div>
    </div>
  );
};

import { ReactNode } from 'react';

interface LayoutProps {
  map: ReactNode;
  children: ReactNode;
}

const Layout = ({ map, children }: LayoutProps) => {
  return (
    <>
      <section className="flex-1 mb-0 min-h-full min-w-full w-full h-full">
        <div className="flex flex-col lg:flex-row">
          <div className="lg:flex-1 min-h-0 min-w-0 ">
            <div className="flex h-[calc(100vh)]">{map}</div>
          </div>
        </div>
      </section>
      {children}
    </>
  );
};

// eslint-disable-next-line react/display-name
export default Layout;

%{?scl:%scl_package rubygem-%{gem_name}}
%{!?scl:%global pkg_name %{name}}

%global gem_name flintlock
%global rubyabi 1.9.1

Summary: A simple application deployer
Name: %{?scl_prefix}rubygem-%{gem_name}
Version: 0.0.1
Release: 1%{?dist}
Group: Development/Languages
License: MIT
URL: https://github.com/jcmcken/flintlock
Source0: %{gem_name}-%{version}.gem
Requires: %{?scl_prefix}ruby(abi) = %{rubyabi}
Requires: %{?scl_prefix}ruby(rubygems) 
Requires: %{?scl_prefix}rubygem(thor) 
Requires: %{?scl_prefix}rubygem(json) 
BuildRequires: %{?scl_prefix}ruby(abi) = %{rubyabi}
BuildRequires: %{?scl_prefix}ruby(rubygems) 
BuildRequires: %{?scl_prefix}rubygems-devel
BuildArch: noarch
Provides: %{?scl_prefix}rubygem(%{gem_name}) = %{version}

%description
A simple application deployer inspired by Heroku's buildpacks.

%prep
%setup -q -c -T
mkdir -p .%{gem_dir}
mkdir -p .%{_bindir}

%{?scl:scl enable %{scl} "}
gem install --local --install-dir .%{gem_dir} \
            --bindir .%{_bindir} \
            --force %{SOURCE0}
%{?scl:"}

%build

%install
mkdir -p %{buildroot}%{gem_dir}
cp -pa .%{gem_dir}/* \
        %{buildroot}%{gem_dir}/

mkdir -p %{buildroot}%{_bindir}
cp -pa .%{_bindir}/* \
        %{buildroot}%{_bindir}/

find %{buildroot}%{gem_instdir}/bin -type f | xargs chmod a+x
find %{buildroot}%{gem_instdir}/lib -type f | xargs chmod ugo+r

%if %{?scl:1}%{!?scl:0}
mkdir -p %{buildroot}%{_root_bindir}
cat << EOF > %{buildroot}%{_root_bindir}/flintlock
#!/bin/bash

scl enable ruby193 "flintlock \$*"
EOF
%endif

%package -n flintlock
Summary: A simple application deployer
Group: Utilities
Requires: %{?scl_prefix}rubygem(flintlock)

%description -n flintlock
A simple application deployer inspired by Heroku's buildpacks.

%files -n flintlock
%if %{?scl:1}%{!?scl:0}
%attr(0755,root,root) %{_root_bindir}/flintlock
%endif

%files
%dir %{gem_instdir}
%attr(0755, root,root) %{_bindir}/flintlock
%{gem_instdir}/bin
%{gem_instdir}/lib
%exclude %{gem_dir}/cache/%{gem_name}-%{version}.gem
%{gem_dir}/specifications/%{gem_name}-%{version}.gemspec
%doc %{gem_instdir}/README.md
%doc %{gem_instdir}/CHANGES.md

%changelog
* Mon May 26 2014 Jon McKenzie - 0.0.1-1
- Initial package

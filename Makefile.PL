use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Catalyst',
    VERSION_FROM => 'lib/Catalyst.pm',
    PREREQ_PM    => {
        CGI::Simple              => 0,
        Class::Accessor::Fast    => 0,
        Class::Data::Inheritable => 0,
        HTML::Entities           => 0,
        HTTP::Headers            => 0,
        Module::Pluggable::Fast  => 0
    }
);

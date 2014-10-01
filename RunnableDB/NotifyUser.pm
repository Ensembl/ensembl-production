=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::ProjectGOTerms::RunnableDB::NotifyUser

=cut

=head1 DESCRIPTION


=cut
package Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::NotifyUser;

use strict;
use base ('Bio::EnsEMBL::Hive::Process');


sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    my $to_species    = $self->param('to_species');
    my $email         = $self->param('email')   || die "'email' parameter is obligatory";
    my $subject       = $self->param('subject') || "An automatic message from your pipeline";
    my $output_dir    = $self->param('output_dir'); 	
    my $text          = "$subject for $to_species the output log file is available at $output_dir.\n";

    open (SENDMAIL, "|sendmail $email");
    print SENDMAIL "Subject: $subject\n";
    print SENDMAIL "\n";
    print SENDMAIL "$text\n";
    close SENDMAIL;
}

sub write_output {
}

1;

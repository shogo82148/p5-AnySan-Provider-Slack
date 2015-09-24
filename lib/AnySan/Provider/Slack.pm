package AnySan::Provider::Slack;
use strict;
use warnings;
our $VERSION = '0.01';

use base 'AnySan::Provider';
our @EXPORT = qw(slack);
use AnySan;
use AnySan::Receive;
use HTTP::Request::Common;
use AnyEvent::HTTP;
use AnyEvent::SlackRTM;
use JSON;
use Encode;

sub slack {
    my(%config) = @_;

    my $self = __PACKAGE__->new(
        client => undef,
        config => \%config,
    );

    # join channels
    my @channels = keys %{ $config{channels} };
    for my $channel (@channels) {
        $self->_call('channels.join', [
            name => $channel,
        ], sub {});
    }

    # get auth info
    $self->_call('auth.test', [], sub {
        my $res = shift;
        $self->{authinfo} = $res;
    });

    my $rtm = AnyEvent::SlackRTM->new($config{token});
    $rtm->on('hello' => sub {
        $self->{keep_alive} = AnyEvent->timer(
            interval => 60,
            cb => sub {
                $rtm->ping;
            },
        );
    });
    $rtm->on('message' => sub {
        my ($rtm, $message) = @_;
        my $authinfo = $self->{authinfo} or return;
        return if $message->{subtype} && $message->{subtype} eq 'bot_message';
        return if $message->{user} && $message->{user} eq $authinfo->{user_id};
        my $receive; $receive = AnySan::Receive->new(
            provider      => 'slack',
            event         => 'message',
            message       => encode_utf8($message->{text} || ''),
            nickname      => encode_utf8($authinfo->{user} || ''),
            from_nickname => encode_utf8($message->{user} || ''),
            attribute     => {
                channel => $message->{channel},
            },
            cb            => sub { $self->event_callback($receive, @_) },
        );
        AnySan->broadcast_message($receive);
    });
    $rtm->start;
    $self->{rtm} = $rtm;

    return $self;
}

sub event_callback {
    my($self, $receive, $type, @args) = @_;

    if ($type eq 'reply') {
        $self->_call('chat.postMessage', [
            channel => $receive->attribute('channel'),
            text    => $args[0],
            as_user => $self->{config}->{as_user} ? 'true' : 'false',
        ], sub {});
    }
}

sub send_message {
    my($self, $message, %args) = @_;

    $self->_call('chat.postMessage', [
        text    => $message,
        channel => $args{channel},
        as_user => $self->{config}->{as_user} ? 'true' : 'false',
        %{ $args{params} || +{} },
    ], sub {});
}

sub _call {
    my ($self, $method, $params, $cb) = @_;
    my $req = POST "https://slack.com/api/$method", [
        token   => $self->{config}{token},
        @$params,
    ];
    my %headers = map { $_ => $req->header($_), } $req->headers->header_field_names;
    my $jd = $self->{json_driver} ||= JSON->new->utf8;
    my $r;
    $r = http_post $req->uri, $req->content, headers => \%headers, sub {
        my $body = shift;
        my $res = $jd->decode($body);
        $cb->($res);
        undef $r;
    };
}

1;
__END__

=head1 NAME

AnySan::Provider::Slack - AnySan provider for Slack

B<THE SOFTWARE IS ALPHA QUALITY. API MAY CHANGE WITHOUT NOTICE.>

=head1 SYNOPSIS

  use AnySan;
  use AnySan::Provider::Slack;
  my $slack = slack
      token => 'YOUR SLACK API TOKEN',
      channels => {
          'general' => {},
      };
  $slack->send_message('slack message', channel => 'C024BE91L');

=head1 AUTHOR

Ichinose Shogo E<lt>shogo82148@gmail.com E<gt>

=head1 SEE ALSO

L<AnySan>, L<AnyEvent::IRC::Client>, L<Slack API|https://api.slack.com/>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

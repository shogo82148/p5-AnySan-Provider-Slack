package AnySan::Provider::Slack;
use strict;
use warnings;
use base 'AnySan::Provider';
our @EXPORT = qw(slack);
use AnySan;
use AnySan::Receive;
use HTTP::Request::Common;
use AnyEvent::HTTP;
use AnyEvent::SlackRTM;
use JSON;

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
        use DDP; p $message;
        my $authinfo = $self->{authinfo} or return;
        return if $message->{user} eq $authinfo->{user_id};
        my $receive; $receive = AnySan::Receive->new(
            provider      => 'slack',
            event         => 'message',
            message       => $message->{text},
            nickname      => $authinfo->{user},
            from_nickname => $message->{user},
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
            as_user => 'true',
            channel => $receive->attribute('channel'),
            text    => $args[0],
        ], sub {});
    }
}

sub send_message {
    my($self, $message, %args) = @_;

    $self->_call('chat.postMessage', [
        as_user => 'true',
        text    => $message,
        channel => $args{channel},
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
    my $r;
    $r = http_post $req->uri, $req->content, headers => \%headers, sub {
        my $body = shift;
        my $res = decode_json($body);
        $cb->($res);
        undef $r;
    };
}

1;


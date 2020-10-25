using Gee;

using Xmpp;
using Dino.Entities;

namespace Dino {

public class Register : StreamInteractionModule, Object{
    public static ModuleIdentity<Register> IDENTITY = new ModuleIdentity<Register>("registration");
    public string id { get { return IDENTITY.id; } }

    private StreamInteractor stream_interactor;
    private Database db;

    public static void start(StreamInteractor stream_interactor, Database db) {
        Register m = new Register(stream_interactor, db);
        stream_interactor.add_module(m);
    }

    private Register(StreamInteractor stream_interactor, Database db) {
        this.stream_interactor = stream_interactor;
        this.db = db;
    }

    public async ConnectionManager.ConnectionError.Source? add_check_account(Account account) {
        ConnectionManager.ConnectionError.Source? ret = null;

        Gee.List<XmppStreamModule> list = new ArrayList<XmppStreamModule>();
        list.add(new Iq.Module());
        list.add(new Sasl.Module(account.bare_jid.to_string(), account.password));

        XmppStreamResult stream_result = yield Xmpp.establish_stream(account.bare_jid.domain_jid, list, Application.print_xmpp);

        if (stream_result.stream == null) {
            if (stream_result.tls_errors != null) {
                ret = ConnectionManager.ConnectionError.Source.TLS;
            }
            return ret;
        }
        XmppStream stream = stream_result.stream;

        SourceFunc callback = add_check_account.callback;
        stream.stream_negotiated.connect(() => {
            if (callback == null) return;
            Idle.add((owned)callback);
        });
        stream.get_module(Sasl.Module.IDENTITY).received_auth_failure.connect((stream, node) => {
            if (callback == null) return;
            ret = ConnectionManager.ConnectionError.Source.SASL;
            Idle.add((owned)callback);
        });
        stream.loop.begin((_, res) => {
            try {
                stream.loop.end(res);
            } catch (Error e) {
                debug("Error connecting to stream: %s", e.message);
            }
            if (callback != null) {
                ret = ConnectionManager.ConnectionError.Source.CONNECTION;
                Idle.add((owned)callback);
            }
        });

        yield;

        try {
            yield stream_result.stream.disconnect();
        } catch (Error e) {}
        return ret;
    }

    public class ServerAvailabilityReturn {
        public bool available { get; set; }
        public TlsCertificateFlags? error_flags { get; set; }
    }

    public static async ServerAvailabilityReturn check_server_availability(Jid jid) {
        ServerAvailabilityReturn ret = new ServerAvailabilityReturn() { available=false };

        Gee.List<XmppStreamModule> list = new ArrayList<XmppStreamModule>();
        list.add(new Iq.Module());

        XmppStreamResult stream_result = yield Xmpp.establish_stream(jid.domain_jid, list, Application.print_xmpp);

        if (stream_result.stream == null) {
            if (stream_result.io_error != null) {
                debug("Error connecting to stream: %s", stream_result.io_error.message);
            }
            if (stream_result.tls_errors != null) {
                ret.error_flags = stream_result.tls_errors;
            }
            return ret;
        }
        XmppStream stream = stream_result.stream;

        SourceFunc callback = check_server_availability.callback;
        stream.stream_negotiated.connect(() => {
            if (callback != null) {
                ret.available = true;
                Idle.add((owned)callback);
            }
        });

        stream.connect.begin((_, res) => {
            try {
                stream.connect.end(res);
            } catch (Error e) {
                debug("Error connecting to stream: %s", e.message);
            }
            if (callback != null) {
                Idle.add((owned)callback);
            }
        });

        yield;

        try {
            yield stream.disconnect();
        } catch (Error e) {}
        return ret;
    }

    public static async Xep.InBandRegistration.Form? get_registration_form(Jid jid) {
        Gee.List<XmppStreamModule> list = new ArrayList<XmppStreamModule>();
        list.add(new Iq.Module());
        list.add(new Xep.InBandRegistration.Module());

        XmppStreamResult stream_result = yield Xmpp.establish_stream(jid.domain_jid, list, Application.print_xmpp);

        if (stream_result.stream == null) {
            return null;
        }
        XmppStream stream = stream_result.stream;

        SourceFunc callback = get_registration_form.callback;

        stream.stream_negotiated.connect(() => {
            if (callback != null) {
                Idle.add((owned)callback);
            }
        });

        stream.connect.begin((_, res) => {
            try {
                stream.connect.end(res);
            } catch (Error e) {
                debug("Error connecting to stream: %s", e.message);
            }
            if (callback != null) {
                Idle.add((owned)callback);
            }
        });

        yield;

        Xep.InBandRegistration.Form? form = null;
        if (stream.negotiation_complete) {
            form = yield stream.get_module(Xep.InBandRegistration.Module.IDENTITY).get_from_server(stream, jid);
        }
        try {
            yield stream.disconnect();
        } catch (Error e) {}

        return form;
    }

    public static async string? submit_form(Jid jid, Xep.InBandRegistration.Form form) {
        Gee.List<XmppStreamModule> list = new ArrayList<XmppStreamModule>();
        list.add(new Iq.Module());
        list.add(new Xep.InBandRegistration.Module());

        XmppStreamResult stream_result = yield Xmpp.establish_stream(jid.domain_jid, list, Application.print_xmpp);

        if (stream_result.stream == null) {
            return null;
        }
        XmppStream stream = stream_result.stream;

        SourceFunc callback = submit_form.callback;

        stream.stream_negotiated.connect(() => {
            if (callback != null) {
                Idle.add((owned)callback);
            }
        });

        stream.connect.begin((_, res) => {
            try {
                stream.connect.end(res);
            } catch (Error e) {
                debug("Error connecting to stream: %s", e.message);
            }
            if (callback != null) {
                Idle.add((owned)callback);
            }
        });

        yield;

        string? ret = null;
        if (stream.negotiation_complete) {
            ret = yield stream.get_module(Xep.InBandRegistration.Module.IDENTITY).submit_to_server(stream, jid, form);
        }
        try {
            yield stream.disconnect();
        } catch (Error e) {}
        return ret;
    }
}

}

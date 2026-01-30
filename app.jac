"""Flask Web UI for WhatsApp Daily Message Automation."""

import os;
import subprocess;
import signal;
import from flask { Flask, render_template, request, jsonify, make_response }
import from dotenv { load_dotenv }


def get_env_file() -> str {
    return os.path.join(os.path.dirname(__file__), ".env");
}


def get_settings() -> dict {
    load_dotenv(override=True);
    chat_names = os.getenv("CHAT_NAME", "").strip("'\"");
    headless_str = os.getenv("HEADLESS", "false").strip("'\"").lower();
    return {
        "chat_names": chat_names,
        "schedule_hour": int(os.getenv("SCHEDULE_HOUR", "21").strip("'\"")),
        "schedule_minute": int(os.getenv("SCHEDULE_MINUTE", "30").strip("'\"")),
        "headless": headless_str == "true"
    };
}


def save_settings(chat_names: str, hour: int, minute: int, headless: bool) {
    env_file = get_env_file();

    # Read current .env content
    f = open(env_file, "r");
    lines = f.readlines();
    f.close();

    # Update values
    new_lines = [];
    for line in lines {
        if line.startswith("CHAT_NAME=") {
            new_lines.append(f"CHAT_NAME={chat_names}\n");
        } elif line.startswith("SCHEDULE_HOUR=") {
            new_lines.append(f"SCHEDULE_HOUR={hour}\n");
        } elif line.startswith("SCHEDULE_MINUTE=") {
            new_lines.append(f"SCHEDULE_MINUTE={minute}\n");
        } elif line.startswith("HEADLESS=") {
            headless_val = "true" if headless else "false";
            new_lines.append(f"HEADLESS={headless_val}\n");
        } else {
            new_lines.append(line);
        }
    }

    # Write back
    f = open(env_file, "w");
    for line in new_lines {
        f.write(line);
    }
    f.close();
}


def index() {
    settings = get_settings();
    resp = make_response(render_template("index.html", settings=settings));
    resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
    resp.headers["Pragma"] = "no-cache";
    resp.headers["Expires"] = "0";
    return resp;
}


def api_get_settings() {
    return jsonify(get_settings());
}


def api_save_settings() {
    data = request.json;
    try {
        chat_names = data.get("chat_names", "");
        hour = int(data.get("schedule_hour", 21));
        minute = int(data.get("schedule_minute", 30));
        headless = data.get("headless", False);

        if hour < 0 or hour > 23 {
            resp = make_response(jsonify({"error": "Hour must be between 0 and 23"}));
            resp.status_code = 400;
            return resp;
        }
        if minute < 0 or minute > 59 {
            resp = make_response(jsonify({"error": "Minute must be between 0 and 59"}));
            resp.status_code = 400;
            return resp;
        }

        save_settings(chat_names, hour, minute, headless);
        return jsonify({"success": True, "message": "Settings saved!"});
    } except Exception as e {
        resp = make_response(jsonify({"error": str(e)}));
        resp.status_code = 400;
        return resp;
    }
}


def api_send_now() {
    print("Executing send_now...");
    try {
        result = subprocess.run(
            ["jac", "run", "send_now.jac"],
            capture_output=True,
            text=True,
            cwd=os.path.dirname(__file__),
            timeout=300
        );
        
        print("--- Subprocess STDOUT ---");
        print(result.stdout);
        print("--- Subprocess STDERR ---");
        print(result.stderr);
        print("-------------------------");
        
        return jsonify({
            "success": result.returncode == 0,
            "output": result.stdout,
            "error": result.stderr
        });
    } except Exception as e {
        print(f"EXCEPTION in api_send_now: {e}");
        resp = make_response(jsonify({"error": str(e)}));
        resp.status_code = 500;
        return resp;
    }
}


def api_test_message() {
    try {
        result = subprocess.run(
            ["jac", "run", "test.jac"],
            capture_output=True,
            text=True,
            cwd=os.path.dirname(__file__),
            timeout=60
        );
        return jsonify({
            "success": result.returncode == 0,
            "output": result.stdout,
            "error": result.stderr
        });
    } except Exception as e {
        resp = make_response(jsonify({"error": str(e)}));
        resp.status_code = 500;
        return resp;
    }
}


def api_start_scheduler() {
    try {
        log_file = os.path.join(os.path.dirname(__file__), "scheduler.log");
        log_f = open(log_file, "w");
        proc = subprocess.Popen(
            ["jac", "run", "src/main.jac"],
            cwd=os.path.dirname(__file__),
            stdout=log_f,
            stderr=log_f
        );
        pid_file = os.path.join(os.path.dirname(__file__), ".scheduler.pid");
        f = open(pid_file, "w");
        f.write(str(proc.pid));
        f.close();
        return jsonify({"success": True, "message": "Scheduler started!", "pid": proc.pid});
    } except Exception as e {
        resp = make_response(jsonify({"error": str(e)}));
        resp.status_code = 500;
        return resp;
    }
}


def api_scheduler_log() {
    log_file = os.path.join(os.path.dirname(__file__), "scheduler.log");
    try {
        if os.path.exists(log_file) {
            f = open(log_file, "r");
            content = f.read();
            f.close();
            # Get last 50 lines
            lines = content.split("\n");
            last_lines = lines[-50:] if lines.__len__() > 50 else lines;
            return jsonify({"log": "\n".join(last_lines)});
        }
        return jsonify({"log": "No log file yet"});
    } except Exception as e {
        return jsonify({"log": f"Error reading log: {e}"});
    }
}


def api_stop_scheduler() {
    pid_file = os.path.join(os.path.dirname(__file__), ".scheduler.pid");
    try {
        if not os.path.exists(pid_file) {
            resp = make_response(jsonify({"error": "Scheduler is not running"}));
            resp.status_code = 400;
            return resp;
        }
        f = open(pid_file, "r");
        pid = int(f.read().strip());
        f.close();
        os.kill(pid, signal.SIGTERM);
        os.remove(pid_file);
        return jsonify({"success": True, "message": "Scheduler stopped!"});
    } except Exception as e {
        if os.path.exists(pid_file) {
            os.remove(pid_file);
        }
        resp = make_response(jsonify({"error": str(e)}));
        resp.status_code = 500;
        return resp;
    }
}


def api_scheduler_status() {
    pid_file = os.path.join(os.path.dirname(__file__), ".scheduler.pid");
    if not os.path.exists(pid_file) {
        return jsonify({"running": False, "pid": None});
    }
    try {
        f = open(pid_file, "r");
        pid = int(f.read().strip());
        f.close();
        os.kill(pid, 0);
        return jsonify({"running": True, "pid": pid});
    } except Exception {
        return jsonify({"running": False, "pid": None});
    }
}


def create_app() -> object {
    load_dotenv();
    flask_app = Flask(__name__);
    flask_app.config["TEMPLATES_AUTO_RELOAD"] = True;

    flask_app.add_url_rule("/", "index", index);
    flask_app.add_url_rule("/api/settings", "api_get_settings", api_get_settings, methods=["GET"]);
    flask_app.add_url_rule("/api/settings", "api_save_settings", api_save_settings, methods=["POST"]);
    flask_app.add_url_rule("/api/send-now", "api_send_now", api_send_now, methods=["POST"]);
    flask_app.add_url_rule("/api/test-message", "api_test_message", api_test_message, methods=["POST"]);
    flask_app.add_url_rule("/api/scheduler/start", "api_start_scheduler", api_start_scheduler, methods=["POST"]);
    flask_app.add_url_rule("/api/scheduler/stop", "api_stop_scheduler", api_stop_scheduler, methods=["POST"]);
    flask_app.add_url_rule("/api/scheduler/status", "api_scheduler_status", api_scheduler_status, methods=["GET"]);
    flask_app.add_url_rule("/api/scheduler/log", "api_scheduler_log", api_scheduler_log, methods=["GET"]);

    return flask_app;
}


with entry {
    print("\n" + "=" * 50);
    print("WhatsApp Daily Message - Control Panel");
    print("=" * 50);
    print("\nOpen http://localhost:5000 in your browser");
    print("Press Ctrl+C to stop\n");

    app = create_app();
    app.run(debug=True, port=5000);
}

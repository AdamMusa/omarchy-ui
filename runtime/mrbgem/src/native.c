#include <mruby.h>
#include <mruby/array.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/string.h>

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static char **argv_from_mrb(mrb_state *mrb, mrb_value array) {
  mrb_int length = RARRAY_LEN(array);
  if (length < 1) mrb_raise(mrb, E_ARGUMENT_ERROR, "command argv cannot be empty");
  char **argv = mrb_calloc(mrb, (size_t)length + 1, sizeof(char *));
  for (mrb_int i = 0; i < length; i++) {
    mrb_value value = mrb_ary_ref(mrb, array, i);
    if (!mrb_string_p(value) || memchr(RSTRING_PTR(value), 0, (size_t)RSTRING_LEN(value)))
      mrb_raise(mrb, E_ARGUMENT_ERROR, "command arguments must be strings without NUL");
    argv[i] = RSTRING_PTR(value);
  }
  return argv;
}

static double monotonic_seconds(void) {
  struct timespec value;
  clock_gettime(CLOCK_MONOTONIC, &value);
  return (double)value.tv_sec + (double)value.tv_nsec / 1000000000.0;
}

static void drain_fd(mrb_state *mrb, int fd, mrb_value output, int *open_flag,
                     mrb_int limit, int *limited) {
  char buffer[4096];
  for (;;) {
    ssize_t count = read(fd, buffer, sizeof(buffer));
    if (count > 0) {
      mrb_int remaining = limit - RSTRING_LEN(output);
      if (remaining > 0) {
        mrb_int append = (mrb_int)count > remaining ? remaining : (mrb_int)count;
        mrb_str_cat(mrb, output, buffer, append);
      }
      if ((mrb_int)count > remaining) *limited = 1;
    }
    else if (count == 0) { close(fd); *open_flag = 0; break; }
    else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) { close(fd); *open_flag = 0; break; }
    else break;
  }
}

static mrb_value native_command(mrb_state *mrb, mrb_value self) {
  mrb_value command;
  mrb_float timeout = 0;
  mrb_int output_limit = 1048576;
  mrb_get_args(mrb, "A|fi", &command, &timeout, &output_limit);
  if (output_limit <= 0) mrb_raise(mrb, E_ARGUMENT_ERROR, "output limit must be positive");
  char **argv = argv_from_mrb(mrb, command);
  int out_pipe[2], err_pipe[2];
  if (pipe(out_pipe) || pipe(err_pipe)) mrb_sys_fail(mrb, "pipe");
  pid_t pid = fork();
  if (pid < 0) mrb_sys_fail(mrb, "fork");
  if (pid == 0) {
    dup2(out_pipe[1], STDOUT_FILENO); dup2(err_pipe[1], STDERR_FILENO);
    close(out_pipe[0]); close(out_pipe[1]); close(err_pipe[0]); close(err_pipe[1]);
    execvp(argv[0], argv);
    _exit(errno == ENOENT ? 127 : 126);
  }
  mrb_free(mrb, argv);
  close(out_pipe[1]); close(err_pipe[1]);
  fcntl(out_pipe[0], F_SETFL, fcntl(out_pipe[0], F_GETFL) | O_NONBLOCK);
  fcntl(err_pipe[0], F_SETFL, fcntl(err_pipe[0], F_GETFL) | O_NONBLOCK);
  mrb_value stdout_value = mrb_str_new(mrb, NULL, 0);
  mrb_value stderr_value = mrb_str_new(mrb, NULL, 0);
  int out_open = 1, err_open = 1, status = 0, exited = 0, timed_out = 0, output_limited = 0;
  double started = monotonic_seconds();
  while (out_open || err_open || !exited) {
    struct pollfd fds[2] = {{out_pipe[0], POLLIN | POLLHUP, 0}, {err_pipe[0], POLLIN | POLLHUP, 0}};
    poll(fds, 2, 20);
    if (out_open && fds[0].revents) drain_fd(mrb, out_pipe[0], stdout_value, &out_open, output_limit, &output_limited);
    if (err_open && fds[1].revents) drain_fd(mrb, err_pipe[0], stderr_value, &err_open, output_limit, &output_limited);
    if (!exited && waitpid(pid, &status, WNOHANG) == pid) exited = 1;
    if (!exited && output_limited) {
      kill(pid, SIGTERM); usleep(100000); kill(pid, SIGKILL); waitpid(pid, &status, 0);
      exited = 1;
    }
    if (!exited && timeout > 0 && monotonic_seconds() - started >= timeout) {
      kill(pid, SIGTERM); usleep(100000); kill(pid, SIGKILL); waitpid(pid, &status, 0);
      exited = 1; timed_out = 1;
    }
  }
  mrb_value result = mrb_hash_new(mrb);
  mrb_hash_set(mrb, result, mrb_str_new_lit(mrb, "stdout"), stdout_value);
  mrb_hash_set(mrb, result, mrb_str_new_lit(mrb, "stderr"), stderr_value);
  mrb_hash_set(mrb, result, mrb_str_new_lit(mrb, "status"), mrb_fixnum_value(WIFEXITED(status) ? WEXITSTATUS(status) : 128));
  mrb_hash_set(mrb, result, mrb_str_new_lit(mrb, "timed_out"), mrb_bool_value(timed_out));
  mrb_hash_set(mrb, result, mrb_str_new_lit(mrb, "output_limited"), mrb_bool_value(output_limited));
  return result;
}

static mrb_value native_spawn(mrb_state *mrb, mrb_value self) {
  mrb_value command, log_value;
  mrb_get_args(mrb, "AS", &command, &log_value);
  char **argv = argv_from_mrb(mrb, command);
  int exec_pipe[2];
  if (pipe(exec_pipe)) mrb_sys_fail(mrb, "pipe");
  if (fcntl(exec_pipe[1], F_SETFD, FD_CLOEXEC) < 0) {
    close(exec_pipe[0]); close(exec_pipe[1]);
    mrb_sys_fail(mrb, "fcntl");
  }
  pid_t pid = fork();
  if (pid < 0) {
    close(exec_pipe[0]); close(exec_pipe[1]);
    mrb_sys_fail(mrb, "fork");
  }
  if (pid == 0) {
    close(exec_pipe[0]);
    setsid();
    int log_fd = open(RSTRING_PTR(log_value), O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (log_fd >= 0) { dup2(log_fd, STDOUT_FILENO); dup2(log_fd, STDERR_FILENO); close(log_fd); }
    execvp(argv[0], argv);
    int exec_errno = errno;
    (void)write(exec_pipe[1], &exec_errno, sizeof(exec_errno));
    _exit(exec_errno == ENOENT ? 127 : 126);
  }
  mrb_free(mrb, argv);
  close(exec_pipe[1]);
  int exec_errno = 0;
  ssize_t count;
  do { count = read(exec_pipe[0], &exec_errno, sizeof(exec_errno)); } while (count < 0 && errno == EINTR);
  close(exec_pipe[0]);
  if (count > 0) {
    (void)waitpid(pid, NULL, 0);
    errno = exec_errno;
    mrb_sys_fail(mrb, "execvp");
  }
  return mrb_fixnum_value(pid);
}

void mrb_omarchy_ui_runtime_gem_init(mrb_state *mrb) {
  struct RClass *module = mrb_define_module(mrb, "OmarchyUI");
  mrb_define_module_function(mrb, module, "native_command", native_command, MRB_ARGS_ARG(1, 2));
  mrb_define_module_function(mrb, module, "spawn_detached", native_spawn, MRB_ARGS_REQ(2));
}

void mrb_omarchy_ui_runtime_gem_final(mrb_state *mrb) { (void)mrb; }

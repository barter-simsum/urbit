/* vere/khan.c
**
*/
#include <inttypes.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <dirent.h>
#include <uv.h>
#include <errno.h>

#include "all.h"
#include "vere/vere.h"

/* u3_chan: incoming control plane connection. used as u3_shan->mor_u's ptr_v.
*/
  typedef struct _u3_chan {
    struct _u3_moor   mor_u;            //  message handler
    c3_w              coq_l;            //  connection number
    struct _u3_shan*  san_u;            //  server backpointer
  } u3_chan;

/* u3_shan: control plane server.
*/
  typedef struct _u3_shan {
    uv_pipe_t         pyp_u;            //  server stream handler
    struct _u3_chan*  can_u;            //  connection list
    struct _u3_khan*  kan_u;            //  device backpointer
  } u3_shan;

/* u3_khan: control plane device.
*/
  typedef struct _u3_khan {
    u3_auto           car_u;            //  driver
    c3_l              sev_l;            //  instance number
    struct _u3_shan*  san_u;            //  server reference
    u3_cue_xeno*      sil_u;            //  cue handle
  } u3_khan;

static const c3_c URB_SOCK_PATH[] = ".urb/khan.sock";

/* _khan_close_cb(): socket close callback.
*/
static void
_khan_close_cb(uv_handle_t* had_u)
{
  c3_free(had_u);
}

static void
_khan_moat_free(void* ptr_v, ssize_t err_i, const c3_c* err_c)
{
  c3_free(ptr_v);
}

static void
_khan_moor_bail(void* ptr_v, ssize_t err_i, const c3_c* err_c)
{
  u3_chan*  can_u = (u3_chan*)ptr_v;
  u3_shan*  san_u = can_u->san_u;
  u3_khan*  kan_u = san_u->kan_u;
  u3_chan*  inn_u;

  if ( err_i != UV_EOF ) {
    u3l_log("khan: bail called %p %zd %s\n", ptr_v, err_i, err_c);
    u3_king_bail();
  }
  else {
    // TODO remove
    u3l_log("khan: eof\n");

    // close socket and remove reference.
    for ( inn_u = san_u->can_u; inn_u; inn_u = (u3_chan*)inn_u->mor_u.nex_u ) {
      if ( (u3_chan*)inn_u->mor_u.nex_u == can_u ) {
        inn_u->mor_u.nex_u = can_u->mor_u.nex_u;
        can_u->mor_u.nex_u = NULL;
        u3_newt_moat_stop((u3_moat*)&can_u->mor_u, _khan_moat_free);
        break;
      }
    }
  }
}

static void
_khan_moor_poke(void* ptr_v, c3_d len_d, c3_y* byt_y)
{
  u3_weak   jar;
  u3_chan*  can_u = (u3_chan*)ptr_v;
  u3_khan*  kan_u = can_u->san_u->kan_u;
  u3_noun   wir;
  u3_noun   cad;

  jar = u3s_cue_xeno_with(kan_u->sil_u, len_d, byt_y);
  if ( u3_none == jar ) {
    _khan_moor_bail(ptr_v, -1, "bad jar");
  }
  else {
    wir = u3nc(u3i_string("khan"),
               u3nt(u3dc("scot", c3__uv, kan_u->sev_l),
                    u3dc("scot", c3__ud, can_u->coq_l),
                    u3_nul));
    cad = u3nc(c3__fyrd, jar);
    u3_auto_plan(&kan_u->car_u, u3_ovum_init(0, c3__k, wir, cad));
  }
}

/* _khan_conn_cb(): socket connection callback.
*/
static void
_khan_conn_cb(uv_stream_t* sem_u, c3_i tas_i)
{
  u3_shan*  san_u = (u3_shan*)sem_u;
  u3_khan*  kan_u = san_u->kan_u;
  u3_chan*  can_u;
  c3_i      err_i;

  can_u = c3_calloc(sizeof(u3_chan));
  can_u->mor_u.ptr_v = can_u;
  can_u->mor_u.pok_f = _khan_moor_poke;
  can_u->mor_u.bal_f = _khan_moor_bail;
  // XX maybe want mug(now) or something
  can_u->coq_l = ( san_u->can_u ) ? 1 + san_u->can_u->coq_l : 0;
  can_u->san_u = san_u;
  err_i = uv_timer_init(u3L, &can_u->mor_u.tim_u);
  c3_assert(!err_i);
  err_i = uv_pipe_init(u3L, &can_u->mor_u.pyp_u, 0);
  c3_assert(!err_i);
  err_i = uv_accept(sem_u, (uv_stream_t*)&can_u->mor_u.pyp_u);
  c3_assert(!err_i);
  u3_newt_read_sync((u3_moat*)&can_u->mor_u);
  can_u->mor_u.nex_u = (u3_moor*)san_u->can_u;
  san_u->can_u = can_u;
}

/* _khan_sock_init(): initialize socket device.
*/
static void
_khan_sock_init(u3_shan* san_u)
{
  // The full socket path is limited to about 108 characters, and we want it to
  // be relative to the pier. So we save our current path, chdir to the pier,
  // open the socket at the desired path, then chdir back. Hopefully there
  // aren't any threads.
  c3_c pax_c[2048];
  c3_i err_i;

  if ( NULL == getcwd(pax_c, sizeof(pax_c)) ) {
    u3l_log("khan: getcwd: %s\n", uv_strerror(errno));
    u3_king_bail();
  }
  if ( 0 != chdir(u3_Host.dir_c) ) {
    u3l_log("khan: chdir: %s\n", uv_strerror(errno));
    u3_king_bail();
  }
  if ( 0 != unlink(URB_SOCK_PATH) && errno != ENOENT ) {
    u3l_log("khan: unlink: %s\n", uv_strerror(errno));
    goto _khan_sock_err_chdir;
  }
  if ( 0 != (err_i = uv_pipe_init(u3L, &san_u->pyp_u, 0)) ) {
    u3l_log("khan: uv_pipe_init: %s\n", uv_strerror(err_i));
    goto _khan_sock_err_chdir;
  }
  if ( 0 != (err_i = uv_pipe_bind(&san_u->pyp_u, URB_SOCK_PATH)) ) {
    u3l_log("khan: uv_pipe_bind: %s\n", uv_strerror(err_i));
    goto _khan_sock_err_chdir;
  }
  if ( 0 != (err_i = uv_listen((uv_stream_t*)&san_u->pyp_u, 0,
                               _khan_conn_cb)) ) {
    u3l_log("khan: uv_listen: %s\n", uv_strerror(err_i));
    goto _khan_sock_err_unlink;
  }
  if ( 0 != chdir(pax_c) ) {
    u3l_log("khan: chdir: %s\n", uv_strerror(errno));
    goto _khan_sock_err_close;
  }
  return;

_khan_sock_err_close:
  uv_close((uv_handle_t*)&san_u->pyp_u, _khan_close_cb);
_khan_sock_err_unlink:
  if ( 0 != unlink(URB_SOCK_PATH) ) {
    u3l_log("khan: unlink: %s\n", uv_strerror(errno));
  }
_khan_sock_err_chdir:
  if ( 0 != chdir(pax_c) ) {
    u3l_log("khan: chdir: %s\n", uv_strerror(errno));
  }
  u3_king_bail();
}

/* _khan_born_news(): initialization complete, open socket.
*/
static void
_khan_born_news(u3_ovum* egg_u, u3_ovum_news new_e)
{
  u3_auto* car_u = egg_u->car_u;
  u3_khan* kan_u = (u3_khan*)car_u;
  u3_shan* san_u;

  if ( u3_ovum_done == new_e ) {
    c3_assert(!kan_u->san_u);
    san_u = c3_calloc(sizeof(*san_u));
    _khan_sock_init(san_u);
    san_u->kan_u = kan_u;
    kan_u->san_u = san_u;
    car_u->liv_o = c3y;
    u3l_log("khan: live on %s/%s\n", u3_Host.dir_c, URB_SOCK_PATH);
  }
}

/* _khan_born_bail(): nonessential failure; log it and keep going.
*/
static void
_khan_born_bail(u3_ovum* egg_u, u3_noun lud)
{
  u3l_log("khan: %%born failure; socket not opened\n");
}

/* _khan_io_talk(): notify %khan that we're live
*/
static void
_khan_io_talk(u3_auto* car_u)
{
  u3_khan* kan_u = (u3_khan*)car_u;

  u3_noun wir = u3nt(c3__khan,
                     u3dc("scot", c3__uv, kan_u->sev_l),
                     u3_nul);
  u3_noun cad = u3nc(c3__born, u3_nul);

  u3_auto_peer(
    u3_auto_plan(car_u, u3_ovum_init(0, c3__k, wir, cad)),
    0,
    _khan_born_news,
    _khan_born_bail);
}

/* _khan_io_kick(): apply effects.
*/
static c3_o
_khan_io_kick(u3_auto* car_u, u3_noun wir, u3_noun cad)
{
  u3_khan* kan_u = (u3_khan*)car_u;

  u3_noun tag, dat, i_wir;
  c3_o ret_o;

  if (  (c3n == u3r_cell(wir, &i_wir, 0))
     || (c3n == u3r_cell(cad, &tag, &dat))
     || (c3__khan != i_wir) )
  {
    ret_o = c3n;
  }
  else {
    ret_o = c3y;
    // TODO do something
  }

  u3z(wir); u3z(cad);
  return ret_o;
}

/* _khan_io_exit(): unlink socket, shut down connections.
*/
static void
_khan_io_exit(u3_auto* car_u)
{
  u3_khan*          kan_u = (u3_khan*)car_u;

  if ( c3y == car_u->liv_o ) {
    c3_c*           pax_c = u3_Host.dir_c;
    c3_w            len_w = strlen(pax_c) + 1 + sizeof(URB_SOCK_PATH);
    c3_c*           paf_c = c3_malloc(len_w);
    c3_i            wit_i;

    wit_i = snprintf(paf_c, len_w, "%s/%s", pax_c, URB_SOCK_PATH);
    c3_assert(wit_i > 0);
    c3_assert(len_w == (c3_w)wit_i + 1);
    // TODO remove
    u3l_log("khan: unlinking %s\n", paf_c);

    if ( 0 != unlink(paf_c) ) {
      u3l_log("khan: failed to unlink socket: %s\n", uv_strerror(errno));
    }
    c3_free(paf_c);

    {
      u3_shan*        san_u = kan_u->san_u;
      u3_chan*        can_u = san_u->can_u;
      u3_chan*        nex_u;

      while ( can_u ) {
        nex_u = (u3_chan*)can_u->mor_u.nex_u;
        u3_newt_moat_stop((u3_moat*)&can_u->mor_u, _khan_moat_free);
        can_u = nex_u;
      }
      uv_close((uv_handle_t*)&san_u->pyp_u, _khan_close_cb);
    }
  }

  u3s_cue_xeno_done(kan_u->sil_u);
  c3_free(kan_u);
}

/* u3_khan(): initialize control plane socket.
*/
u3_auto*
u3_khan_io_init(u3_pier* pir_u)
{
  u3_khan* kan_u = c3_calloc(sizeof(*kan_u));
  u3_auto* car_u = &kan_u->car_u;

  kan_u->sil_u = u3s_cue_xeno_init();
  car_u->nam_m = c3__khan;
  car_u->liv_o = c3n;
  car_u->io.talk_f = _khan_io_talk;
  car_u->io.kick_f = _khan_io_kick;
  car_u->io.exit_f = _khan_io_exit;

  {
    u3_noun         now;
    struct timeval  tim_u;

    gettimeofday(&tim_u, 0);
    now = u3_time_in_tv(&tim_u);
    kan_u->sev_l = u3r_mug(now);
    u3z(now);
  }

  return car_u;
}

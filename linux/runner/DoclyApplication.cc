#include "DoclyApplication.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

G_DEFINE_TYPE(DoclyApplication, docly_application, GTK_TYPE_APPLICATION)

// Implements GApplication::activate.
static void docly_application_activate(GApplication* application) {
  DoclyApplication* self = DOCLY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_header_bar_set_show_title_buttons(header_bar, TRUE);
  gtk_header_bar_set_title(header_bar, "Docly");
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

  gtk_window_set_title(window, "Docly");
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  gtk_application_add_window(GTK_APPLICATION(application), window);
}

// Implements GApplication::local_command_line.
static gboolean docly_application_local_command_line(
    GApplication* application,
    gchar*** arguments,
    int* exit_status) {
  DoclyApplication* self = DOCLY_APPLICATION(application);
  *exit_status = 0;
  return FALSE;
}

// Implements GApplication::startup.
static void docly_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(docly_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void docly_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(docly_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void docly_application_dispose(GObject* object) {
  G_OBJECT_CLASS(docly_application_parent_class)->dispose(object);
}

static void docly_application_class_init(DoclyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = docly_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      docly_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = docly_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = docly_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = docly_application_dispose;
}

static void docly_application_init(DoclyApplication* self) {}

DoclyApplication* docly_application_new() {
  return DOCLY_APPLICATION(g_object_new(docly_application_get_type(),
                                        "application-id", "com.pixeldev.Docly",
                                        "flags", G_APPLICATION_NON_UNIQUE,
                                        nullptr));
}
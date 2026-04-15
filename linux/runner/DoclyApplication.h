#ifndef FLUTTER_DOCLY_APPLICATION_H_
#define FLUTTER_DOCLY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(DoclyApplication, docly_application, DOCLY,
                     APPLICATION, GtkApplication)

/**
 * docly_application_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #DoclyApplication.
 */
DoclyApplication* docly_application_new();

#endif  // FLUTTER_DOCLY_APPLICATION_H_
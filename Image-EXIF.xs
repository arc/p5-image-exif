#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "exif.h"
#include "jpeg.h"

struct exiftags *et = NULL;
struct exifprop *ep = NULL;
unsigned short dumplvl = 0;

static int
read_data(char *name)
{
    int mark, first = 0;
    unsigned int len, rlen;
    unsigned char *exifbuf = NULL;
    FILE *fp = fopen(name, "rb");

    if (!fp) {
        exifdie((const char *)strerror(errno));
        return 2;
    }

    while (jpegscan(fp, &mark, &len, !(first++))) {
        if (mark != JPEG_M_APP1) {
            if (fseek(fp, len, SEEK_CUR)) {
                exifdie((const char *)strerror(errno));
                free(exifbuf);
                fclose(fp);
                return 2;
            }
            continue;
        }

        exifbuf = (unsigned char *) malloc(len);
        if (!exifbuf) {
            exifdie((const char *)strerror(errno));
            free(exifbuf);
            fclose(fp);
            return 2;
        }

        rlen = fread(exifbuf, 1, len, fp);
        if (rlen != len) {
            exifwarn("error reading JPEG (length mismatch)");
            free(exifbuf);
            fclose(fp);
            return 1;
        }

        et = exifparse(exifbuf, len);

        if (et && et->props)
            break;

        exifwarn("couldn't find Exif data");
        free(exifbuf);
        fclose(fp);
        return 1;
    }

    free(exifbuf);
    fclose(fp);
    return 0;
}

static long
get_props(char *field, char *value)
{
    int pas = TRUE;

    if (ep && dumplvl) {

        /* Take care of point-and-shoot values. */

        if (ep->lvl == ED_PAS)
            ep->lvl = pas ? ED_CAM : ED_IMG;

        /* For now, just treat overridden & bad values as verbose. */

        if (ep->lvl == ED_OVR || ep->lvl == ED_BAD)
            ep->lvl = ED_VRB;

        if (ep->lvl == dumplvl) {
            strcpy(field, ep->descr ? ep->descr : ep->name);
            if (!ep->str)
                sprintf(value, "%d", ep->value);
            else
                strcpy(value, ep->str);
        }

        ep = ep->next;
    }

    return (long) ep;
}

static void
close_application()
{
    if (et) {
        exiffree(et);
        et = NULL;
    }
}

MODULE = Image::EXIF            PACKAGE = Image::EXIF

PROTOTYPES: DISABLE

int
c_read_file(name)
    char *name
CODE:
    RETVAL = read_data(name);
OUTPUT:
    RETVAL

void
c_get_camera_info()
CODE:
    dumplvl = ED_CAM;
    if (et)
        ep = et->props;

void
c_get_image_info()
CODE:
    dumplvl = ED_IMG;
    if (et)
        ep = et->props;

void
c_get_other_info()
CODE:
    dumplvl = ED_VRB;
    if (et)
        ep = et->props;

void
c_get_unknown_info()
CODE:
    dumplvl = ED_UNK;
    if (et)
        ep = et->props;

int
c_fetch()
PPCODE:
    char field[256] = "";
    char value[256] = "";

    int rc = get_props(field, value);
    if (rc) {
        EXTEND(sp, 2);
        PUSHs(sv_2mortal(newSVpv((char*)field, 0)));
        PUSHs(sv_2mortal(newSVpv((char*)value, 0)));
    }

void
c_close_all()
PPCODE:
    close_application();

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

    if (!fp)
        croak("Can't open file %s: %s", name, strerror(errno));

    while (jpegscan(fp, &mark, &len, !(first++))) {
        if (mark != JPEG_M_APP1) {
            if (fseek(fp, len, SEEK_CUR)) {
                free(exifbuf);
                fclose(fp);
                croak("Can't seek in file %s: %s", name, strerror(errno));
            }
            continue;
        }

        exifbuf = (unsigned char *) malloc(len);
        if (!exifbuf) {
            fclose(fp);
            croak("malloc failed");
        }

        rlen = fread(exifbuf, 1, len, fp);
        if (rlen != len) {
            free(exifbuf);
            fclose(fp);
            croak("error reading JPEG %s: length mismatch", name);
        }

        et = exifparse(exifbuf, len);

        if (et && et->props)
            break;

        warn("couldn't find EXIF data in %s", name);
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
    if (ep && dumplvl) {

        if (ep->lvl == ED_PAS)
            /* Take care of point-and-shoot values. */
            ep->lvl = ED_CAM;
        else if (ep->lvl == ED_OVR || ep->lvl == ED_BAD)
            /* For now, just treat overridden & bad values as verbose. */
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

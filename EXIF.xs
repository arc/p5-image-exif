#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "exif.h"
#include "jpeg.h"

static char error[256];

struct exiftags *et = NULL;
struct exifprop *ep = NULL;
unsigned short dumplvl = 0;

static int
read_data(char *fname)
{
	static char _file_name[1024] = "";

        int mark, first = 0;
        unsigned int len, rlen;
	unsigned char *exifbuf = NULL;

	FILE *fpn;
	char *mode;

#ifdef WIN32
        mode = "rb";
#else
        mode = "r";
#endif

	if(strcmp(fname, _file_name)){
		fpn = fopen(fname, mode);
		if (fpn) 
			strcpy(_file_name, fname);
		else
			_file_name[0] = '\0';
	} else {
		return 0;
	}

	if (fpn == NULL){
		exifdie((const char *)strerror(errno));
		return 2;
	}

	while (jpegscan(fpn, &mark, &len, !(first++))) {

                if (mark != JPEG_M_APP1) {
                        if (fseek(fpn, len, SEEK_CUR)){
                                exifdie((const char *)strerror(errno));
				free (exifbuf);
				fclose (fpn);
				return 2;
			}
                        continue;
                }
		
                exifbuf = (unsigned char *)malloc(len);
                if (!exifbuf){
                        exifdie((const char *)strerror(errno));
			free (exifbuf);
			fclose (fpn);
			return 2;
		}

                rlen = fread(exifbuf, 1, len, fpn);
                if (rlen != len) {
                        exifwarn("error reading JPEG (length mismatch)");
                        free(exifbuf);
			fclose (fpn);
                        return (1);
                }

                et = exifparse(exifbuf, len);

		if (et && et->props){
			break;
		} else {
	                exifwarn("couldn't find Exif data");
			free (exifbuf);
			fclose (fpn);
        	        return (1);
		}
	}

	free (exifbuf);
	fclose (fpn);
        return (0);
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

	return (long)ep;
}

static int
close_application()
{
	if (et)
	{
		exiffree(et);
		et = NULL;
	}
}

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant(char *name, int len, int arg)
{
    errno = EINVAL;
    return 0;
}

MODULE = Image::EXIF		PACKAGE = Image::EXIF		


double
constant(sv,arg)
    PREINIT:
	STRLEN		len;
    INPUT:
	SV *		sv
	char *		s = SvPV(sv, len);
	int		arg
    CODE:
	RETVAL = constant(s,len,arg);
    OUTPUT:
	RETVAL

int
c_read_file(fname)
	char *fname
CODE:
	error[0] = '\0';
	RETVAL = 0;

	RETVAL = read_data(fname);
OUTPUT:
	RETVAL

int
c_get_camera_info()
CODE:
	dumplvl = ED_CAM;
	if (et)
		ep = et->props;

int
c_get_image_info()
CODE:
	dumplvl = ED_IMG;
	if (et)
		ep = et->props;

int
c_get_other_info()
CODE:
	dumplvl = ED_VRB;
	if (et)
		ep = et->props;

int
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

	if (ep) {
		int rc = get_props(field, value);
		EXTEND(sp, 2);
		PUSHs(sv_2mortal(newSVpv((char*)field, 0)));
		PUSHs(sv_2mortal(newSVpv((char*)value, 0)));
	}

int
c_errstr()
PPCODE:
	if (strlen(error)){
		EXTEND(sp, 1);
		PUSHs(sv_2mortal(newSVpv((char*)error, 0)));
	}

int
c_close_all()
PPCODE:
	close_application();

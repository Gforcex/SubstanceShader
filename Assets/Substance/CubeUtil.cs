using UnityEngine;
using System;
using System.IO;

public class CubeUtil
{
    public static void cubeLookup(ref float s, ref float t, ref ulong face, Vector3 dir)
    {
        float xmag = Mathf.Abs(dir.x);
        float ymag = Mathf.Abs(dir.y);
        float zmag = Mathf.Abs(dir.z);

        //NOTE: Because the result is the unfiltered nearest pixel hit, edges of the cube are
        // going to be tricky. A cube edge lies where magx and magz are equal and could be considered
        // either the x or z face. We just hammer it to be the x face and return face=x, s=1. --Andres
        if (xmag >= ymag && xmag >= zmag)
        {
            if (dir.x >= 0.0f) { face = 0; } //+x
            else { face = 1; } //-x
        }
        else if (ymag >= xmag && ymag >= zmag)
        {
            if (dir.y >= 0.0f) { face = 2; } //+y
            else { face = 3; } //-y
        }
        else
        {
            if (dir.z >= 0.0f) { face = 4; } //+z
            else { face = 5; } //-z
        }
        switch (face)
        {
            case 0:
                s = 0.5f * (-dir.z / xmag + 1.0f);
                t = 0.5f * (-dir.y / xmag + 1.0f);
                break;
            case 1:
                s = 0.5f * (dir.z / xmag + 1.0f);
                t = 0.5f * (-dir.y / xmag + 1.0f);
                break;
            case 2:
                s = 0.5f * (dir.x / ymag + 1.0f);
                t = 0.5f * (dir.z / ymag + 1.0f);
                break;
            case 3:
                s = 0.5f * (dir.x / ymag + 1.0f);
                t = 0.5f * (-dir.z / ymag + 1.0f);
                break;
            case 4:
                s = 0.5f * (dir.x / zmag + 1.0f);
                t = 0.5f * (-dir.y / zmag + 1.0f);
                break;
            case 5:
                s = 0.5f * (-dir.x / zmag + 1.0f);
                t = 0.5f * (-dir.y / zmag + 1.0f);
                break;
        };
    }
    // cube face uv to vector
    public static void invCubeLookup(ref Vector3 dst, ref float weight, ulong face, ulong col, ulong row, ulong faceSize)
    {
        float invFaceSize = 2f / (float)faceSize;
        float x = ((float)col + 0.5f) * invFaceSize - 1f;
        float y = ((float)row + 0.5f) * invFaceSize - 1f;
        switch (face)
        {
            case 0: //+x rotated 180
                dst[0] = 1f; dst[1] = -y; dst[2] = -x;
                break;
            case 1: //-x rotated 180
                dst[0] = -1f; dst[1] = -y; dst[2] = x;
                break;
            case 2: //+y
                dst[0] = x; dst[1] = 1f; dst[2] = y;
                break;
            case 3: //-y
                dst[0] = x; dst[1] = -1f; dst[2] = -y;
                break;
            case 4: //+z
                dst[0] = x; dst[1] = -y; dst[2] = 1f;
                break;
            case 5: //-z rotated 180
                dst[0] = -x; dst[1] = -y; dst[2] = -1f;
                break;
        };
        // solid angle is: 4/( (X^2 + Y^2 + Z^2)^(3/2) ) = 4/mag^3
        float mag = dst.magnitude;
        weight = 4f / (mag * mag * mag);
        dst /= mag; //normalize
    }
    // lat-long uv to vector
    public static void invLatLongLookup(ref Vector3 dst, ref float cosPhi, ulong col, ulong row, ulong width, ulong height)
    {
        float uvshift = 0.5f;
        float u = ((float)col + uvshift) / (float)width;
        float v = ((float)row + uvshift) / (float)height;
        float theta = -2f * Mathf.PI * u - 0.5f * Mathf.PI; // minus half a pie to match unity reflection maps
        float phi = 0.5f * Mathf.PI * (2 * v - 1);
        cosPhi = Mathf.Cos(phi);
        dst.x = Mathf.Cos(theta) * cosPhi;
        dst.y = Mathf.Sin(phi);
        dst.z = Mathf.Sin(theta) * cosPhi;
    }
    public static void cubeToLatLongLookup(ref float pano_u, ref float pano_v, ulong face, ulong col, ulong row, ulong faceSize)
    {
        Vector3 dir = new Vector3();
        float ignore = -1f;
        invCubeLookup(ref dir, ref ignore, face, col, row, faceSize);
        pano_v = Mathf.Asin(dir.y) / Mathf.PI + 0.5f;
        pano_u = 0.5f * Mathf.Atan2(-dir.x, -dir.z) / Mathf.PI;
        pano_u = Mathf.Repeat(pano_u, 1f);
    }
    public static void latLongToCubeLookup(/*cube*/ ref float cube_u, ref float cube_v, ref ulong face, /*pano*/ ulong col, ulong row, ulong width, ulong height)
    {
        Vector3 dir = new Vector3();
        float ignore = -1f;
        invLatLongLookup(ref dir, ref ignore, col, row, width, height);
        cubeLookup(ref cube_u, ref cube_v, ref face, dir);
    }
    public static void rotationToInvLatLong(out float u, out float v, Quaternion rot)
    {
        u = rot.eulerAngles.y;
        v = rot.eulerAngles.x;
        u = Mathf.Repeat(u, 360f) / 360f;
        v = 1f - Mathf.Repeat(v + 90, 360f) / 180f;
    }
    public static void dirToLatLong(out float u, out float v, Vector3 dir)
    {
        dir = dir.normalized;
        u = 0.5f * Mathf.Atan2(-dir.x, -dir.z) / Mathf.PI;
        u = Mathf.Repeat(u, 1f);
        v = Mathf.Asin(dir.y) / Mathf.PI + 0.5f;
        v = 1f - Mathf.Repeat(v, 1f);
    }

    public static void applyGamma(ref Color c, float gamma)
    {
        c.r = Mathf.Pow(c.r, gamma);
        c.g = Mathf.Pow(c.g, gamma);
        c.b = Mathf.Pow(c.b, gamma);
    }
    public static void applyGamma(ref Color[] c, float gamma)
    {
        for (int i = 0; i < c.Length; ++i)
        {
            c[i].r = Mathf.Pow(c[i].r, gamma);
            c[i].g = Mathf.Pow(c[i].g, gamma);
            c[i].b = Mathf.Pow(c[i].b, gamma);
        }
    }
    public static void applyGamma(ref Color[] dst, Color[] src, float gamma)
    {
        for (int i = 0; i < src.Length; ++i)
        {
            dst[i].r = Mathf.Pow(src[i].r, gamma);
            dst[i].g = Mathf.Pow(src[i].g, gamma);
            dst[i].b = Mathf.Pow(src[i].b, gamma);
            dst[i].a = src[i].a; //NOTE: this is here for lazy programmers who use applyGamma to copy data
        }
    }

    public static void applyGamma(ref Color[] dst, int dst_offset, Color[] src, int src_offset, int count, float gamma)
    {
        for (int i = 0; i < count && i < src.Length; ++i)
        {
            dst[i + dst_offset].r = Mathf.Pow(src[i + src_offset].r, gamma);
            dst[i + dst_offset].g = Mathf.Pow(src[i + src_offset].g, gamma);
            dst[i + dst_offset].b = Mathf.Pow(src[i + src_offset].b, gamma);
            dst[i + dst_offset].a = src[i + src_offset].a; //NOTE: this is here for lazy programmers who use applyGamma to copy data00
        }
    }

    public static void applyGamma2D(ref Texture2D tex, float gamma)
    {
        for (int mip = 0; mip < tex.mipmapCount; ++mip)
        {
            Color[] c = tex.GetPixels(mip);
            applyGamma(ref c, gamma);
            tex.SetPixels(c);
        }
        tex.Apply(false);
    }

    public static void clearTo(ref Color[] c, Color color)
    {
        for (int i = 0; i < c.Length; ++i)
        {
            c[i] = color;
        }
    }
    public static void clearTo2D(ref Texture2D tex, Color color)
    {
        for (int mip = 0; mip < tex.mipmapCount; ++mip)
        {
            Color[] c = tex.GetPixels(mip);
            clearTo(ref c, color);
            tex.SetPixels(c, mip);
        }
        tex.Apply(false);
    }

    public static void clearChecker2D(ref Texture2D tex)
    {
        Color gray0 = new Color(0.25f, 0.25f, 0.25f, 0.25f);
        Color gray1 = new Color(0.50f, 0.50f, 0.50f, 0.25f);
        Color[] c = tex.GetPixels();
        int w = tex.width;
        int h = tex.height;
        int sqw = h / 4;    //width of square
        for (int x = 0; x < w; ++x)
            for (int y = 0; y < h; ++y)
            {
                if (((x / sqw) % 2) == ((y / sqw) % 2)) c[y * w + x] = gray0;
                else c[y * w + x] = gray1;
            }
        tex.SetPixels(c);
        tex.Apply(false);
    }

    public static void clearCheckerCube(ref Cubemap cube)
    {
        Color gray0 = new Color(0.25f, 0.25f, 0.25f, 0.25f);
        Color gray1 = new Color(0.50f, 0.50f, 0.50f, 0.25f);
        Color[] c = cube.GetPixels(CubemapFace.NegativeX);
        int w = cube.width;
        int sqw = Mathf.Max(1, w / 4);  //width of square
        for (int face = 0; face < 6; ++face)
        {
            for (int x = 0; x < w; ++x)
                for (int y = 0; y < w; ++y)
                {
                    if (((x / sqw) % 2) == ((y / sqw) % 2)) c[y * w + x] = gray0;
                    else c[y * w + x] = gray1;
                }
            cube.SetPixels(c, (CubemapFace)face);
        }
        cube.Apply(true);
    }
};


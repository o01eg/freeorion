//! GiGi - A GUI for OpenGL
//!
//!  Copyright (C) 2003-2008 T. Zachary Laine <whatwasthataddress@gmail.com>
//!  Copyright (C) 2013-2020 The FreeOrion Project
//!
//! Released under the GNU Lesser General Public License 2.1 or later.
//! Some Rights Reserved.  See COPYING file or https://www.gnu.org/licenses/lgpl-2.1.txt
//! SPDX-License-Identifier: LGPL-2.1-or-later

//! @file GG/StaticGraphic.h
//!
//! Contains the StaticGraphic class, a fixed image control.

#ifndef _GG_StaticGraphic_h_
#define _GG_StaticGraphic_h_


#include <GG/Control.h>
#include <GG/Texture.h>
#include <GG/VectorTexture.h>


namespace GG {

/** Styles for StaticGraphic controls. */
GG_FLAG_TYPE(GraphicStyle);
constexpr GraphicStyle GRAPHIC_NONE          (0);       ///< Default style selected.
constexpr GraphicStyle GRAPHIC_VCENTER       (1 << 0);  ///< Centers graphic vertically.
constexpr GraphicStyle GRAPHIC_TOP           (1 << 1);  ///< Top-justifies graphic.
constexpr GraphicStyle GRAPHIC_BOTTOM        (1 << 2);  ///< Justifies the graphic to the bottom of the rectangle.
constexpr GraphicStyle GRAPHIC_CENTER        (1 << 3);  ///< Centers graphic horizontally in the rectangle.
constexpr GraphicStyle GRAPHIC_LEFT          (1 << 4);  ///< Aligns graphic to the left.
constexpr GraphicStyle GRAPHIC_RIGHT         (1 << 5);  ///< Aligns graphic to the right.
constexpr GraphicStyle GRAPHIC_FITGRAPHIC    (1 << 6);  ///< Scales graphic to fit within the StaticGraphic's window dimensions.
constexpr GraphicStyle GRAPHIC_SHRINKFIT     (1 << 7);  ///< Like GRAPHIC_FITGRAPHIC, but this one only scales the image if it otherwise would not fit in the window.
constexpr GraphicStyle GRAPHIC_PROPSCALE     (1 << 8);  ///< If GRAPHIC_FITGRAPHIC or GRAPHIC_SHRINKFIT is used, this ensures scaling is done proportionally.


/** \brief A simple, non-interactive window that displays a GG::SubTexture.

    Though the SubTexture displayed in a StaticGraphic is fixed, its size is
    not; the image can be scaled (proportionately or not) to fit in the
    StaticGraphic's window area. \see GraphicStyle*/
class GG_API StaticGraphic : public Control
{
public:
     ///< creates a StaticGraphic from a pre-existing Texture.
    explicit StaticGraphic(std::shared_ptr<Texture> texture,
                           Flags<GraphicStyle> style = GRAPHIC_NONE,
                           Flags<WndFlag> flags = NO_WND_FLAGS);

    ///< creates a StaticGraphic from a pre-existing SubTexture.
    explicit StaticGraphic(SubTexture subtexture,
                           Flags<GraphicStyle> style = GRAPHIC_NONE,
                           Flags<WndFlag> flags = NO_WND_FLAGS);

    ///< creates a StaticGraphic from a pre-existing VectorTexture
    explicit StaticGraphic(std::shared_ptr<VectorTexture> vector_texture,
                           Flags<GraphicStyle> style = GRAPHIC_NONE,
                           Flags<WndFlag> flags = NO_WND_FLAGS);

    /** Returns the style of the StaticGraphic \see GraphicStyle */
    Flags<GraphicStyle> Style() const;

    /** Returns the area in which the graphic is actually rendered, in
        UpperLeft()-relative coordinates.  This may not be the entire area of
        the StaticGraphic, based on the style being used. */
    Rect RenderedArea() const;

    const SubTexture& GetTexture() const;
    const std::shared_ptr<VectorTexture>& GetVectorTexture() const;

    const boost::filesystem::path& GetTexturePath() const;

    void Render() override;

    /** Sets the style flags, and perfroms sanity checking \see
        GraphicStyle */
    void SetStyle(Flags<GraphicStyle> style);

    /** Sets the texture */
    void SetTexture(const std::shared_ptr<Texture>& texture);
    void SetTexture(const SubTexture& subtexture);
    void SetTexture(const std::shared_ptr<VectorTexture>& vector_texture);

private:
    void ValidateStyle();   ///< ensures that the style flags are consistent

    SubTexture                      m_graphic;
    std::shared_ptr<VectorTexture>  m_vector_texture;
    Flags<GraphicStyle>             m_style;        ///< position of texture wrt the window area
};

}


#endif

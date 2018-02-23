/**********************************************************************************************
    Copyright (C) 2014 Oliver Eichler oliver.eichler@gmx.de

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

**********************************************************************************************/

#include "CMainWindow.h"
#include "gis/CGisWorkspace.h"
#include "gis/ovl/CGisItemOvlArea.h"
#include "gis/ovl/CScrOptOvlArea.h"
#include "helpers/CDraw.h"
#include "mouse/IMouse.h"

CScrOptOvlArea::CScrOptOvlArea(CGisItemOvlArea *area, const QPoint &point, IMouse *parent)
    : IScrOpt(parent)
    , key(area->getKey())
{
    setupUi(this);
    setOrigin(point);
    label->setFont(CMainWindow::self().getMapFont());
    label->setText(area->getInfo(IGisItem::eFeatureShowName));
    adjustSize();

    anchor = area->getPointCloseBy(point);
    if((anchor - point).manhattanLength() > 50)
    {
        anchor = point;
    }
    move(anchor.toPoint() + QPoint(-width()/2,SCR_OPT_OFFSET));
    toolNogo->setChecked(area->isNogo());
    show();

    connect(toolEditDetails, &QToolButton::clicked, this, &CScrOptOvlArea::hide);
    connect(toolDelete,      &QToolButton::clicked, this, &CScrOptOvlArea::hide);
    connect(toolCopy,        &QToolButton::clicked, this, &CScrOptOvlArea::hide);
    connect(toolEdit,        &QToolButton::clicked, this, &CScrOptOvlArea::hide);

    connect(toolEditDetails, &QToolButton::clicked, this, &CScrOptOvlArea::slotEditDetails);
    connect(toolDelete,      &QToolButton::clicked, this, &CScrOptOvlArea::slotDelete);
    connect(toolCopy,        &QToolButton::clicked, this, &CScrOptOvlArea::slotCopy);
    connect(toolEdit,        &QToolButton::clicked, this, &CScrOptOvlArea::slotEdit);
    connect(toolNogo,        &QToolButton::clicked, this, &CScrOptOvlArea::slotNogo);
}

CScrOptOvlArea::~CScrOptOvlArea()
{
}

void CScrOptOvlArea::slotEditDetails()
{
    CGisWorkspace::self().editItemByKey(key);
    close();
}

void CScrOptOvlArea::slotCopy()
{
    CGisWorkspace::self().copyItemByKey(key);
    close();
}

void CScrOptOvlArea::slotDelete()
{
    CGisWorkspace::self().delItemByKey(key);
    close();
}

void CScrOptOvlArea::slotEdit()
{
    CGisWorkspace::self().editAreaByKey(key);
    close();
}

void CScrOptOvlArea::slotNogo()
{
    CGisWorkspace::self().toggleNogoItem(key);
    close();
}

void CScrOptOvlArea::draw(QPainter& p)
{
    IGisItem * item = CGisWorkspace::self().getItemByKey(key);
    if(nullptr == item)
    {
        QWidget::deleteLater();
        return;
    }
    item->drawHighlight(p);

    CDraw::bubble(p, geometry(), anchor.toPoint());
}